class TasksController < ApplicationController
  before_action :authenticate!
  before_action :set_task, only: [:show, :update, :destroy]

  def index
    page     = params[:page].to_i
    per_page = (params[:per_page] || 20).to_i
    offset   = page * per_page

    tasks = Task.where(user: current_user).offset(offset).limit(per_page)
    render json: tasks
  end

  def create
    task = current_user.tasks.new(task_params)
    if task.save
      render json: task, status: :created
    else
      render json: { errors: task.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def show
    render json: @task
  end

  def update
    if @task.update(task_params)
      render json: @task
    else
      render json: { errors: @task.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @task.update!(deleted_at: Time.current)
    render json: @task
  end

  def by_status
    tasks = Task.where(user: current_user, status: params[:status])
    render json: tasks
  end

  private

  def set_task
    @task = Task.find(params[:id])
  end

  def task_params
    params.permit(:title, :description, :priority, :status)
  end
end
