class UserNameChangeRequest < ApplicationRecord
  after_initialize :initialize_attributes, if: :new_record?
  validates :user_id, :original_name, :desired_name, presence: true
  validates :status, inclusion: { :in => %w(pending approved rejected) }
  belongs_to :user
  belongs_to :approver, :class_name => "User", optional: true
  validate :not_limited, :on => :create
  validates :desired_name, user_name: true
  attr_accessor :skip_limited_validation

  def initialize_attributes
    self.user_id ||= CurrentUser.user.id
    self.original_name ||= CurrentUser.user.name
  end

  def self.pending
    where(:status => "pending")
  end

  def self.approved
    where(:status => "approved")
  end

  def self.search(params)
    q = super

    if params[:current_name].present?
      q = q.where("user_id = ?", User.name_to_id(params[:current_name]))
    end

    if params[:original_name].present?
      q = q.where("lower(original_name) = ?", params[:original_name].downcase.tr(" ", "_"))
    end

    if params[:desired_name].present?
      q = q.where("lower(desired_name) = ?", params[:desired_name].downcase.tr(" ", "_"))
    end

    q.apply_default_order(params)
  end

  def rejected?
    status == "rejected"
  end

  def approved?
    status == "approved"
  end

  def pending?
    status == "pending"
  end

  def approve!
    update(:status => "approved", :approver_id => CurrentUser.user.id)
    user.update_attribute(:name, desired_name)
    body = "Your name change request has been approved. Be sure to log in with your new user name."
    Dmail.create_automated(:title => "Name change request approved", :body => body, :to_id => user_id)
    ModAction.log(:user_name_change, {user_id: user.id, old_name: original_name, new_name: desired_name})
  end

  def not_limited
    return true if skip_limited_validation == true
    if UserNameChangeRequest.where("user_id = ? and created_at >= ?", CurrentUser.user.id, 1.week.ago).exists?
      errors.add(:base, "You can only submit one name change request per week")
      return false
    else
      return true
    end
  end

  def hidden_attributes
    if CurrentUser.is_admin? || user == CurrentUser.user
      []
    else
      super + [:change_reason, :rejection_reason]
    end
  end
end
