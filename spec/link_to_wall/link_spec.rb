require 'spec_helper'

describe LinkParse do
  it "should return valid picture" do
    params = LinkParse.get_html("http://www.koolinar.ru/recipe/view/103241")
    params[:picture].to_s.should match(/public\/images\/thumbs.+r103241_large\.jpg/i)
  end

  it "should return valid icon" do
    params = LinkParse.get_html("http://www.koolinar.ru/recipe/view/103241")
    params[:icon].to_s.should match(/http:\/\/www\.koolinar\.ru\/favicon\.ico/i)
  end

  it "should return valid params picture only picture" do
    params = LinkParse.get_html("http://cs305609.userapi.com/u131914279/-14/y_a4ed77c4.jpg")
    params[:picture].to_s.should match(/public\/images\/thumbs.+y_a4ed77c4\.jpg/i)
  end

  it "should return valid params subject only picture" do
    params = LinkParse.get_html("http://cs305609.userapi.com/u131914279/-14/y_a4ed77c4.jpg")
    params[:subject].to_s.should match(/http:\/\/cs305609\.userapi\.com\/u131914279\/-14\/y_a4ed77c4\.jpg/i)
  end

  it "should return valid params video youtube link" do
    params = LinkParse.get_html("http://www.youtube.com/watch?v=f09jdMNK3G4&feature=g-all-f&context=G2900e8dFAAAAAAAADAA")
    params[:video].to_s.should match(/http:\/\/www\.youtube\.com\/v\/f09jdMNK3G4\?version=3&autohide=1/i)
  end

  it "should return valid params picture youtube link" do
    params = LinkParse.get_html("http://www.youtube.com/watch?v=f09jdMNK3G4&feature=g-all-f&context=G2900e8dFAAAAAAAADAA")
    params[:picture].to_s.should match(/public\/images\/thumbs.+hqdefault\.jpg/i)
  end

  it "should return valid tmp pictures" do
    params = LinkParse.get_html("http://www.koolinar.ru/recipe/view/103241", true)
    params[:tmp_pictures].size.should equal 23
  end
end