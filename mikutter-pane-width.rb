

Plugin.create :mikutter_homo do |service|
  command(:thin_pane,
          name: 'ペインを縮小',
          condition: lambda { |opt| true },
          visible: true,
          role: :tab) do |opt|
    tab = opt.widget.is_a?(Plugin::GUI::Tab) ? opt.widget : opt.widget.ancestor_of(Plugin::GUI::Tab)

    i_pane = tab.ancestor_of(Plugin::GUI::Pane)
    pane = Plugin.create(:gtk).widgetof(i_pane)
    window = Plugin.create(:gtk).widgetof(tab.ancestor_of(Plugin::GUI::Window))

    pane.rel_size -= 0.2

    if pane.rel_size < 0.2
      pane.rel_size = 0.2
    end

    tmp = UserConfig[:homo_pane_sizes]
    tmp ||= {}

    tmp = tmp.melt

    tmp[i_pane.slug] = pane.rel_size

    UserConfig[:homo_pane_sizes] = tmp

    window.adjust_pane_size

  end

  command(:wide_pane,
          name: 'ペインを拡大',
          condition: lambda { |opt| true },
          visible: true,
          role: :tab) do |opt|
    tab = opt.widget.is_a?(Plugin::GUI::Tab) ? opt.widget : opt.widget.ancestor_of(Plugin::GUI::Tab)

    i_pane = tab.ancestor_of(Plugin::GUI::Pane)
    pane = Plugin.create(:gtk).widgetof(i_pane)
    window = Plugin.create(:gtk).widgetof(tab.ancestor_of(Plugin::GUI::Window))

    pane.rel_size += 0.2

    tmp = UserConfig[:homo_pane_sizes]
    tmp ||= {}

    tmp = tmp.melt

    tmp[i_pane.slug] = pane.rel_size

    UserConfig[:homo_pane_sizes] = tmp

    window.adjust_pane_size
  end

  class ::Gtk::Notebook
    attr_accessor :rel_size

    alias :initialize_homo :initialize

    def initialize
      initialize_homo

      @rel_size = 1.0
    end
  end

  class ::Gtk::MikutterWindow
    def adjust_pane_size
      if @panes.children.empty?
        return
      end

      sum = @panes.children.inject(0) { |s, pane| s += pane.rel_size }

      base_width = allocation.width / sum

      @panes.children.each { |pane|
        pane.set_size_request(base_width * pane.rel_size, pane.allocation.height)
      }
    end

    alias :initialize_homo :initialize

    def initialize(imaginally, *args)
      initialize_homo(imaginally, *args)

      @panes.homogeneous = false

      def @panes.window=(win)
        @window = win
      end

      @panes.window = self

      @panes.instance_eval {
        alias :remove_homo :remove

        def remove(widget)
          result = remove_homo(widget)

          if children.size == 1
            children[0].rel_size = 1.0
          end

          @window.adjust_pane_size

          result
        end

        alias :pack_start_homo :pack_start

        def pack_start(child, expand = true, fill = true, padding = 0)
          result = pack_start_homo(child, expand, fill, padding)
          @window.adjust_pane_size

          result
        end

        alias :pack_end_homo :pack_end

        def pack_end(child, expand = true, fill = true, padding = 0)
          result = pack_end_homo(child, expand, fill, padding)
          @window.adjust_pane_size

          result
        end
      }

      ssc(:event){ |window, event|
        if event.is_a? Gdk::EventConfigure
          window.adjust_pane_size
        end

        false
      }
     end
  end

  Plugin.create(:gtk).instance_eval {
    alias :create_pane_homo :create_pane

    def create_pane(i_pane)
      pane = create_pane_homo(i_pane)

      if UserConfig[:homo_pane_sizes] && UserConfig[:homo_pane_sizes][i_pane.slug]
        pane.rel_size = UserConfig[:homo_pane_sizes][i_pane.slug]
      end

      pane
    end

    alias :pane_order_delete_homo :pane_order_delete

    def pane_order_delete(i_pane)
      result = pane_order_delete_homo(i_pane)

      if UserConfig[:homo_pane_sizes] && UserConfig[:homo_pane_sizes][i_pane.slug]
        tmp = UserConfig[:homo_pane_sizes]
        tmp ||= {}

        tmp = tmp.melt

        tmp.delete(i_pane.slug)

        UserConfig[:homo_pane_sizes] = tmp
      end

      result
    end
  }
end
