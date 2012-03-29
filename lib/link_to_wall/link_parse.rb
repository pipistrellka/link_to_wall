# coding: utf-8
module LinkParse

def self.get_html(url, tmp = false)
  @tmp = tmp
  @agent = Mechanize.new

  uri = URI.parse(url)
  @params = {:host => uri.host}
  raise StandardError, "Неправильный адрес ссылки" if @params[:host].nil?
  #если ссылка на картинку
  if url =~ /.*\.(jpe*g)|(gif)$/i
    img =  Magick::Image.from_blob(@agent.get_file(url)).first
    save_image(url, img)
    @params.merge!({:subject => url })
  else
   @page = @agent.get(url)  rescue raise(StandardError, 'Данная страница не отвечает')
   get_info()
   get_icon()
#   если нужен предпросмотр берем все картинки
   if tmp
     @params.merge!({:tmp_pictures => [] })
     get_images(/\.(jpe*g)|(php)|(ashx)|(gif)$/i, 70,1000, true)
   else
     domen = @params[:host] =~ /.*\..*\.[\w]*/ ? @params[:host].scan(/.*\.(.*\.[\w]*)/).first.first : @params[:host]
     #ищем картинку
     return @params if @params.key?("picture")
     get_images(/#{domen}.*\.(jpe*g)|(php)|(ashx)$/i, 120,700)
     get_images(/#{domen}.*\.(jpe*g)|(php)|(ashx)|(gif)$/i, 120,700) unless @params.key?(:picture)
     get_images(/\.(jpe*g)|(php)|(ashx)$/i, 120,700) unless @params.key?(:picture)
     get_images(/\.(jpe*g)|(php)|(ashx)$/i, 30,1000) unless @params.key?(:picture)
   end
    return @params
  end
rescue => err
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
    save_image(img_url, img) if img
 end
 @params.merge!({:subject => subject || @page.title, :body => body,:video => video})
rescue => err
  raise StandardError, err
end

def self.get_icon
  mech = Mechanize.new
  ico = mech.get_file("http://#{@params[:host]}/favicon.ico")
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
  mech = Mechanize.new
  urls =  @page.images.map do |image|
     image.url  rescue next
  end
  urls.uniq!
  urls.each do |img_url|
    if img_url.to_s =~ reg && img_url !~ /(banner)|(user)/
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
    end
  end
end



def self.save_image(img_url, img, tmp=false)
      # сохраняем название, удаляем лишние хвосты
      name = Time.now.to_i.to_s + img_url.to_s.split('/').last.scan(/(.*\.[\w]+)[?.]*/).first.first
      thumb = tmp ? img : img.resize_to_fit(90, 90)
      Dir.mkdir "public/images/thumbs" rescue nil
      begin
        thumb.write "public/images/thumbs/#{name}"
        until File.exists?("public/images/thumbs/#{name}")
           sleep 2
        end
      rescue
      end
      if tmp
        @params[:tmp_pictures].push "public/images/thumbs/#{name}"
      else
        @params.merge!({:picture => "public/images/thumbs/#{name}"})
      end
 end
end
