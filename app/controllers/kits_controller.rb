class KitsController < ApplicationController
  VALID_GRADES = Kit::GRADE_NORMALIZATION.values.uniq.freeze
  VALID_STATUSES = Kit::STATUSES.freeze

  def index
    @tab = params[:tab] || "collection"
    @kits = Kit.all
    @turbo_frame_request = request.headers["Turbo-Frame"] == "kits_grid"

    # Tab filtering
    if @tab == "wishlist"
      @kits = @kits.wishlist
    else
      @kits = @kits.collection
    end

    # Search
    if params[:search].present?
      search = "%#{params[:search]}%"
      @kits = @kits.where(
        "title LIKE ? OR full_title LIKE ? OR topic LIKE ?",
        search, search, search
      )
    end

    # Filters
    @kits = @kits.where(grade_abbr: params[:grade]) if params[:grade].present?
    @kits = @kits.where(scale: params[:scale]) if params[:scale].present?
    @kits = @kits.where(brand: params[:brand]) if params[:brand].present?
    @kits = @kits.where(status: params[:status]) if params[:status].present? && @tab != "wishlist"

    # Sorting
    @kits = @kits.order(sort_column => sort_direction)

    # Pagination
    @pagy, @kits = pagy_countless(@kits, limit: 20)

    # Filter options for sidebar (scoped to current tab)
    base = @tab == "wishlist" ? Kit.wishlist : Kit.collection
    @grades  = base.where.not(grade_abbr: nil).distinct.pluck(:grade_abbr).sort
    @scales  = base.distinct.pluck(:scale).compact.sort
    @brands  = base.distinct.pluck(:brand).compact.sort
    @statuses = VALID_STATUSES.reject { |s| s == "wishlist" }
  end

  def pick
    @grades = Kit.collection.where.not(grade_abbr: nil).distinct.pluck(:grade_abbr).sort
    @scales = Kit.collection.distinct.pluck(:scale).compact.sort
    @brands = Kit.collection.distinct.pluck(:brand).compact.sort

    if params[:roll].present?
      candidates = Kit.unbuilt
      candidates = candidates.where(grade_abbr: params[:grade]) if params[:grade].present?
      candidates = candidates.where(scale: params[:scale]) if params[:scale].present?
      candidates = candidates.where(brand: params[:brand]) if params[:brand].present?
      @picked = candidates.order("RANDOM()").first
    end
  end

  private

  def sort_column
    allowed = %w[title brand scale grade_abbr status]
    allowed.include?(params[:sort]) ? params[:sort] : "title"
  end

  def sort_direction
    params[:direction] == "desc" ? :desc : :asc
  end
end
