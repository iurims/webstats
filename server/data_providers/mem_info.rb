class DataProviders::MemInfo
  def initialize(settings)
    @settings = self.class.default_settings.merge(settings)

    @readings = []
    @mutex = Mutex.new

    @thread = Thread.new do
      while(true)
        out = {}
        out[:total], out[:free], out[:buffers], out[:cached] = IO.readlines("/proc/meminfo")[0..4].map { |l| l =~ /^.*?\: +(.*?) kB$/; $1.to_i / 1024.0 }
        out[:free_total] = out[:free] + out[:buffers] + out[:cached]

        @mutex.synchronize do
          @readings.unshift(out)
          @readings.pop while @readings.length > 5
        end
        sleep(@settings[:update_rate])
      end
    end
  end

  def get
    out = { :total => 0, :free => 0, :buffers => 0, :cached => 0, :free_total => 0 }
    @mutex.synchronize do
      unless @readings.empty?
        out = @readings.first.dup
        out[:status] = 'warning' unless @readings.detect { |r| r[:free] > 5 }
        out[:status] = 'danger' unless @readings.detect { |r| r[:free_total] > 1 }
      end
    end
    out
  end

  def renderer
    information.merge({ :contents => %{
sc.innerHTML = "<div class='major_figure'><span class='title'>Free</span><span class='figure'>" + data_source['free'] + "</span><span class='unit'>mb</span></div>" +
"<div class='major_figure'><span class='title'>Free -buffers/cache</span><span class='figure'>" + data_source['free_total'] + "</span><span class='unit'>mb</span></div>" +
"<div class='major_figure'><span class='title'>Total</span><span class='figure'>" + data_source['total'] + "</span><span class='unit'>mb</span></div>";
} })
  end

  def self.default_settings
    { :update_rate => 2.5 }
  end

  def information
    { :name => "Memory Info", :in_sentence => 'Memory Usage', :importance => 90 }
  end

  def kill
    @thread.kill
  end
end