class RMQ
  def initialize
    @selected_dirty = true
    $rmq_initialized ||= 0
    $rmq_initialized += 1
    #mp $rmq_initialized
  end

  #def finalize
    #mp 'finalize' # Never called
    #$rmq_initialized -= 1
    #mp $rmq_initialized
    #super
  #end

  def originated_from=(value)
    if value
      if value.is_a?(Potion::Activity)
        @originated_from = value
        @activity = value
      elsif value.is_a?(PMScreen) || value.is_a?(PMListScreen)
        @originated_from = value
      elsif value.is_a?(Potion::View)
        @originated_from = value
      elsif value.is_a?(RMQStylesheet)
        @originated_from = value.controller
      else
        @originated_from = nil
        #debug.log_detailed('Invalid originated_from', objects: {value: value})
        #mp "Invalid originated_from: #{value.inspect}"
      end
    else
      @originated_from = nil
    end
    @originated_from
  end

  def originated_from
    @originated_from
  end

  def parent_rmq
    @_parent_rmq
  end
  def parent_rmq=(value)
    #debug.assert(value.is_a?(RMQ) || value.nil?, 'Invalid parent_rmq', { value: value })
    @_parent_rmq = value
  end

  def root?
    # TODO broken
    (selected.length == 1) && (selected.first == @originated_from)
  end

  def originated_from_or_its_view
    if @originated_from.is_a?(Potion::Activity) || @originated_from.is_a?(PMScreen)
      @originated_from.root_view
    elsif @originated_from.is_a?(Potion::View)
      @originated_from
    end

    #if @originated_from.is_a?(Potion::Activity) || @originated_from.is_a?(PMScreen)
      #@originated_from.root_view
    #else
      #@originated_from
    #end
  end

  def get
    sel = self.selected
    if sel.length == 1
      sel.first
    else
      sel
    end
  end

  def origin_views
    if pq = self.parent_rmq
      pq.selected
    else
      root_view
    end
  end

  def wrap(view_one, *views) # These strange params is because of RMA bug
    views = [views] unless views.is_a?(Potion::ArrayList) # TODO, WTF, RM bug?
    views.unshift(view_one)
    views.flatten!
    views.select!{ |v| v.is_a?(Potion::View) }
    RMQ.create_with_array_and_selectors(views, views, @originated_from, self)
  end

  def log(opt = nil)
    if opt == :tree
      mp tree_to_s(selected)
      sleep 0.1 # Hack, TODO, fix async problem
      return
    end

    wide = (opt == :wide)
    out =  "\n id          |object id   |scr| class                 | style_name              | frame                                 |"
    out << "\n" unless wide
    out <<   " sv id       |object id   |een| superview             | subviews count          | tags                                  |"
    line =   " ––––––––––––|------------|–––|–––––––––––––––––––––––|–––––––––––––––––––––––––|–––––––––––––––––––––––––––––––––––––––|\n"
    out << "\n"
    out << line.chop if wide
    out << line

    selected.each do |view|
      out << " #{view.id.to_s.ljust(12)}|"
      out << " #{view.object_id.to_s.ljust(12)}|"
      out << (view.rmq_data.screen_root_view? ? " √ |" : "   |")

      name = view.short_class_name
      name = name[(name.length - 21)..name.length] if name.length > 21
      out << " #{name.ljust(22)}|"

      #out << " #{""[0..23].ljust(24)}|" # TODO change to real stylname
      out << " #{(view.rmq_data.style_name.to_s || '')[0..23].ljust(24)}|" # TODO change to real stylname
      s = ""
      #if view.origin
        #format = '#0.#'
        s = " {l: #{view.x}"
        s << ", t: #{view.y}"
        s << ", w: #{view.width}"
        s << ", h: #{view.height}}"
      #end
      out << s.ljust(36)
      out << "   |"
      out << "\n" unless wide
      if view.superview
        out << " #{view.superview.id.to_s.ljust(12)}|"
        out << "           |"
        out << "   |"
        out << " #{(view.superview ? view.superview.short_class_name : '')[0..21].ljust(22)}|"
      end
      out << " #{view.subviews.length.to_s.ljust(23)} |"
      #out << "  #{view.subviews.length.to_s.rjust(8)} #{view.superview.short_class_name.ljust(20)} #{view.superview.object_id.to_s.rjust(10)}"
      out << " #{view.rmq_data.tag_names.join(',').ljust(38)}|"
      out << "\n"
      out << line unless wide
    end

    mp out
    sleep 0.1 # Hack, TODO, fix async problem
  end

  def log_tree
    self.log :tree
  end

  def tree_to_s(selected_views, depth = 0)
    out = ""

    mp 1

    selected_views.each do |view|
      mp 2
      mp view.rmq_data.tags
      if depth == 0
        out << "\n"
      else
        mp 3
        0.upto(depth - 1) do |i|
          mp 4
          out << (i == (depth - 1) ? "    ├" : "    │")
        end
      end

      out << '───'

      mp 5
      out << "#{view.id}|#{view.object_id} "
      out << "SCREEN ROOT/" if view.rmq_data.screen_root_view?
      out << "#{view.short_class_name[0..21]}"
      out << "  ( :#{view.rmq_data.style_name.to_s[0..23]} )" if view.rmq_data.style_name
      if view.rmq_data.tag_names.length > 0
        mp 6
        mp view.rmq_data.tag_names.inspect
        out << "  [ #{view.rmq_data.tag_names.join(',')} ]"
      end

      #if view.origin
        #format = '#0.#'
        s = "   {l: #{view.x}"
        s << ", t: #{view.y}"
        s << ", w: #{view.width}"
        s << ", h: #{view.height}}"
        out << s
      #end

      out << "\n"
      out << tree_to_s(view.subviews, depth + 1)
    end

    out
  end

  def inspect
    out = "RMQ #{self.object_id}. #{self.count} selected. selectors: #{self.selectors}. .log for more info"
    out << "\n[#{selected.first.inspect}]" if self.count == 1
    out
  end

  # Do not use
  def selected=(value)
    @_selected = value
    @selected_dirty = false
  end

  def selected
    if @selected_dirty
      @_selected = []

      if RMQ.is_blank?(self.selectors)
        if orig = originated_from_or_its_view
          @_selected << orig
        end
      #elsif self.selectors.length == 1 and self.selectors.first.is_a?(Java::Lang::Integer)
        ### Special case where we find by id
        #@_selected << self.root_view.findViewById(self.selectors.first)
      else
        working_selectors = self.selectors.dup

        extract_views_from_selectors(@_selected, working_selectors)

        unless RMQ.is_blank?(working_selectors)
          subviews = all_subviews_for(root_view)

          #return @_selected
          subviews.each do |subview|
            @_selected << subview if match(subview, working_selectors)
          end
        end

      end

      #@_selected.each do |s|
        #unless s.is_a?(Potion::View)
          #mp "bad selected: #{s}"
          #caller
        #end
      #end

      @selected_dirty = false
    else
      @_selected ||= []
    end

    @_selected
  end

  def extract_views_from_selectors(view_container, working_selectors)
    unless RMQ.is_blank?(working_selectors)
      working_selectors.delete_if do |selector|
        if selector.is_a?(Potion::View)
          view_container << selector
          true
        end
      end
    end
  end

  def all_subviews_for(view)
    out = []
    return out unless view.is_a?(Potion::ViewGroup)

    needs_flattening = false

    (0...view.getChildCount).each_with_index do |i|
      sbv = view.getChildAt(i)
      if sbv && view != sbv
        out << sbv
        if sbv.is_a?(Potion::ViewGroup) && sbv.getChildCount > 0
          needs_flattening = true
          out << all_subviews_for(sbv)
        end
      end
    end

    out.flatten! if needs_flattening
    out
  end

  #def all_superviews_for(view, out = [])
    #if (sv = view.superview)
      #out << sv

      ## Stop at root_view of screen or activity
      #unless (sv.rmq_data.screen_root_view?) || (sv == self.activity.root_view) # TODO speed this up if needed
        #all_superviews_for(sv, out)
      #end
    #end
    #out
  #end

end # RMQ

__END__

findViewById(android.R.id.content) returns the View that hosts the content you supplied in setContentView().
  Beyond that, try getRootView() (called on any View) to retrieve "the topmost view in the current view hierarchy".



we_care_about_this = getWindow.getDecorView.findViewById(Android::R::Id::Content)`
now we can traverse:
`we_care_about_this.getChildCount` and `we_care_about_this.getChildAt(0)`


 Activity host = (Activity) view.getContext()

2. view.isFocused()
