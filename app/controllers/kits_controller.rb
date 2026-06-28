class KitsController < ApplicationController
  VALID_GRADES = Kit::GRADE_NORMALIZATION.values.uniq.freeze
  VALID_STATUSES = Kit::STATUSES.freeze

  def index
    @tab = params[:tab] || "collection"
    @searching = params[:search].present?
    @kits = Kit.all
    @turbo_frame_request = request.headers["Turbo-Frame"] == "kits_grid"

    # Tab filtering — skipped when a search query is present (search spans all kits)
    unless @searching
      if @tab == "wishlist"
        @kits = @kits.wishlist
      else
        @kits = @kits.collection
      end
    end

    # Search — name only for now
    if @searching
      @kits = @kits.where("title LIKE ?", "%#{params[:search]}%")
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
    load_filter_options(base)
    @statuses = VALID_STATUSES.reject { |s| s == "wishlist" }
  end

  def pick
    load_filter_options(Kit.collection)

    if params[:roll].present?
      candidates = Kit.unbuilt
      candidates = candidates.where(grade_abbr: params[:grade]) if params[:grade].present?
      candidates = candidates.where(scale: params[:scale]) if params[:scale].present?
      candidates = candidates.where(brand: params[:brand]) if params[:brand].present?
      @picked = candidates.order("RANDOM()").first
    end
  end

  private

  def load_filter_options(scope)
    @grades = scope.where.not(grade_abbr: nil).distinct.pluck(:grade_abbr).sort
    @scales = scope.distinct.pluck(:scale).compact.sort_by { |s| scale_sort_key(s) }
    @brands = scope.distinct.pluck(:brand).compact.sort
  end

  # Order scales by their denominator (1:1, 1:12, 1:18, ...) rather than
  # alphabetically. Non-numeric values like "No" sort last.
  def scale_sort_key(scale)
    denominator = scale[/\A\d+:(\d+)\z/, 1]
    denominator ? denominator.to_i : Float::INFINITY
  end

  def sort_column
    allowed = %w[title brand scale grade_abbr status]
    allowed.include?(params[:sort]) ? params[:sort] : "title"
  end

  def sort_direction
    params[:direction] == "desc" ? :desc : :asc
  end
end
