# frozen_string_literal: true

# Base class for all page elements
class PageElement < Ohm::Model
  include Ohm::DataTypes
  include Ohm::Callbacks

  attribute :position, Type::Integer
  attribute :metadata, Type::Hash
  attribute :content_type # paragraph, image, table, link

  reference :page, :Page

  index :position
  index :content_type

  def self.next_position(page)
    (page.elements.max_by(&:position)&.position || 0) + 1
  end
end

class Image < PageElement
  attribute :url
  attribute :caption
  attribute :alt_text
  attribute :dimensions, Type::Hash # {width: x, height: y}

  def initialize(*)
    super
    self.content_type = 'image'
  end

  index :url
end

class Table < PageElement
  attribute :headers, Type::Array
  attribute :caption
  # list :rows ,

  def initialize(*)
    super
    self.content_type = 'table'
  end

  def add_row(data)
    rows.add(data.to_json)
  end

  def get_rows
    rows.map { |r| JSON.parse(r) }
  end
end

class Link < PageElement
  attribute :url
  attribute :text
  attribute :target # _blank, _self, etc.
  attribute :relationship # nofollow, noopener, etc.

  def initialize(*)
    super
    self.content_type = 'link'
  end

  index :url
  index :text
end

class Page < Ohm::Model
  include Ohm::DataTypes
  include Ohm::Callbacks

  attribute :content
  attribute :number, Type::Integer
  attribute :metadata, Type::Hash

  list :elements, :PageElement

  index :number
  index :text_file_id

  # Element addition methods
  def add_paragraph(text)
    paragraph = Paragraph.create(
      text: text,
      page: self,
      position: PageElement.next_position(self)
    )
    elements.add(paragraph)
    paragraph
  end

  def add_image(data)
    image = Image.create(
      url: data[:url],
      caption: data[:caption],
      alt_text: data[:alt_text],
      dimensions: data[:dimensions],
      page: self,
      position: PageElement.next_position(self)
    )
    elements.add(image)
    image
  end

  def add_table(data)
    table = Table.create(
      headers: data[:headers],
      caption: data[:caption],
      page: self,
      position: PageElement.next_position(self)
    )
    data[:rows]&.each { |row| table.add_row(row) }
    elements.add(table)
    table
  end

  def add_link(data)
    link = Link.create(
      url: data[:url],
      text: data[:text],
      target: data[:target],
      relationship: data[:relationship],
      page: self,
      position: PageElement.next_position(self)
    )
    elements.add(link)
    link
  end

  # Retrieval methods with type filtering
  def retrieve_elements_by_type(type)
    elements.select { |e| e.content_type == type }.sort_by(&:position)
  end

  def paragraphs
    retrieve_elements_by_type('paragraph')
  end

  def images
    retrieve_elements_by_type('image')
  end

  def tables
    retrieve_elements_by_type('table')
  end

  def links
    retrieve_elements_by_type('link')
  end

  # Get elements in order
  def ordered_elements
    elements.sort_by(&:position)
  end
end

# page = text_object.add_page(content: "Page 1", number: 1)

# # Add different types of content
# page.add_paragraph("Introduction text...")
# page.add_image(
#   url: "/images/diagram.png",
#   caption: "System Architecture",
#   alt_text: "Diagram showing system components",
#   dimensions: {width: 800, height: 600}
# )
# page.add_table(
#   headers: ["Name", "Value"],
#   rows: [["Key1", "Value1"], ["Key2", "Value2"]],
#   caption: "Configuration Settings"
# )
# page.add_link(
#   url: "https://example.com",
#   text: "Learn More",
#   target: "_blank",
#   relationship: "noopener"
# )

# # Retrieve content in order
# page.ordered_elements.each do |element|
#   case element.content_type
#   when 'paragraph'
#     puts "Text: #{element.text}"
#   when 'image'
#     puts "Image: #{element.caption}"
#   when 'table'
#     puts "Table: #{element.caption}"
#   when 'link'
#     puts "Link: #{element.text} (#{element.url})"
#   end
# end
