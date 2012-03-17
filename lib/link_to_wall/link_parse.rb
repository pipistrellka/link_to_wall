# coding: utf-8
module LinkParse
 #require "RMagick"
 #require 'uri'
 #require "timeout"
 #require 'mechanize_encoding_hook'

def self.get_html(url, tmp = false)
  @tmp = tmp
  @agent = Mechanize.new
  #@agent.post_connect_hooks << MechanizeEncodingHook.new
  uri = URI.parse(url)
  @params = {:host => uri.host}
  raise StandardError, "Неправильный адрес ссылки" if @params[:host].nil?
  #если ссылка на картинку
  if url =~ /.*\.(jpe*g)|(gif)/i
    img =  Magick::Image.from_blob(@agent.get_file(url)).first
    save_image(url, img)
    @params.merge!({:subject => url })
  else
   @page = @agent.get(url)  rescue raise(StandardError, 'Данная страница не отвечает')
   get_info()
   get_icon() if tmp
   #@link.video.sub!(/\/e\//, "/v/") unless @link.video.nil?
   domen = @params[:host] =~ /.*\..*\.[\w]*/ ? @params[:host].scan(/.*\.(.*\.[\w]*)/).first.first : @params[:host]
#   если нужен предпросмотр берем все картинки
   if tmp
     @params.merge!({:tmp_pictures => [] })
     get_images(/#{domen}.*\.(jpe*g)|(php)|(ashx)|(gif)$/i, 120,1000, true)
     get_images(/\.(jpe*g)|(php)|(ashx)$/i, 70,1000, true) unless @params.key?("picture")
#     get_images(/.*\.(jpe*g)|(png)|(php)|(ashx)|(gif)/i, 120,1000, true) #if @params[:tmp_pictures].empty?
     pid = fork do
       #TODO так не работает
        #exec("#{Rails.root}/syncs.sh #{Rails.public}/all_image/thumbs")
        exec("#{RAILS_ROOT}/syncs.sh #{RAILS_ROOT}/public/all_image/thumbs")
      end
     Process.detach(pid)
     sleep 10
   else
     #ищем картинку
     return @params if @params.key?("picture")
     get_images(/#{domen}.*\.(jpe*g)|(php)|(ashx)$/i, 120,700)
     get_images(/#{domen}.*\.(jpe*g)|(php)|(ashx)|(gif)$/i, 120,700) unless @params.key?("picture")
     get_images(/\.(jpe*g)|(php)|(ashx)$/i, 120,700) unless @params.key?("picture")
     get_images(/\.(jpe*g)|(php)|(ashx)$/i, 30,1000) unless @params.key?("picture")
   end
    return @params
  end
rescue => err
  puts err
  puts err.backtrace
  raise StandardError, err
end

#/*
#  Парсим meta тэги
#  если картинка определена в meta (youtube, rutube), картинку сохраняем
#  если названия нет в meta тэгах , берем из <title>
#*/
def self.get_info()
 img_url, subject, body, video  = nil
 @page.search('head > meta').map do |node|
    if node['name'] && node['content']
      (name, content) = node['name'], node['content']
      body = content if name =~ /description/i
      subject = content if name =~ /title/	# если нет то title
    elsif node['property'] && node['content']
     (property, content) = node['property'], node['content']
      video = content if property =~ /og:video$/
      img_url = content if property =~ /og:image/
      body = content if property =~ /og:description/ && body.nil?
      subject = content if property =~ /[og:]*title/ && subject.nil?
    else
      next
    end
 end
 if img_url
    mech = Mechanize.new
    img =  Magick::Image.from_blob(mech.get_file(img_url)).first
#    если картинка определена через og:image, то дальще не ищем не ищем
#    TODO картинки youtube
    save_image(img_url, img) if img
 end
 @params.merge!({:subject => subject || @page.title, :body => body,:video => video})
rescue => err
  puts err
  puts err.backtrace
  raise StandardError, err
end

def self.get_icon
  mech = Mechanize.new
  ico = mech.get_file("http://#{@params[:host]}/favicon.ico")
  puts "url for ico => #{ico}"
  raise StandardError, "havn't icon" if ico == ""
  @params.merge!({:icon => "http://#{@params[:host]}/favicon.ico"})
rescue
  @page.search('head > link').map do |node|
    if node['rel'] && node['href']
      @params.merge!({:icon =>  node['href'] =~ /^http/ ? node['href'] : "http://#{@params[:host]}/#{node['href']}"}) if node['rel'] =~ /icon/i
    end
  end

end

#/*
#  reg - регулярное выражение для поиска
#  Сначала ищем jpeg картинки с адресом текущего домена. картинка не должна быть слишком маленькой и большой(только для стены)
#  Если не найдено ни одной картинки, ищем картинки с адресом сторонних доменнов и gif|png в том числе
#  min_size - минимальный размер картинки
#  max_size - максимальный размер картинки
#  tmp - картинки для предосмотра, по умолчанию false
#  сохраняем картинки удовлетворяющие условию
#*/
def self.get_images(reg, min_size, max_size, tmp=false)
  puts reg, "******"
  mech = Mechanize.new
  urls =  @page.images.map do |image|
    image.url  rescue next
  end
  urls.uniq!
  urls.each do |img_url|
#    img_url = image.url  rescue next
    if img_url =~ reg && img_url !~ /(banner)|(user)/
      puts "url for image => #{img_url}"
      begin
        Timeout.timeout(5) do
          @img =  Magick::Image.from_blob(mech.get_file(img_url)).first
          raise StandardError, "Execption in block"
        end
      rescue Timeout::Error
        next
      rescue  StandardError
        if @img.columns > min_size && @img.rows > min_size && @img.columns <= max_size
          save_image(img_url, @img, tmp)
          break unless tmp
        end
        next
      end
#     img =  Magick::Image.from_blob(mech.get_file(img_url)).first rescue next
     # проверяем на размер, если меньше 700 не считаем главной картинкой
   end
  end
end



def self.save_image(img_url, img, tmp=false)
      # сохраняем название, удаляем лишние хвосты
      name = Time.now.to_i.to_s + img_url.split('/').last.scan(/(.*\.[\w]+)[?.]*/).first.first
      thumb = tmp ? img : img.resize_to_fit(90, 90)
      Dir.mkdir "public/all_image/thumbs" rescue nil
      thumb.write "public/all_image/thumbs/#{name}"
      until File.exists?("public/all_image/thumbs/#{name}")
        sleep 2
      end
      if tmp
        @params[:tmp_pictures].push "public/all_image/thumbs/#{name}"
      else
        @params.merge!({:picture => "public/all_image/thumbs/#{name}"})
      end
 end




end
