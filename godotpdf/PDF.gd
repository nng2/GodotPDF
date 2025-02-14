extends Control

var _xref = []
var _xrefOffset = 0
var _pages = []
var _fonts = []
var _fontList = []
var _title = ""
var _creator = ""
var _pageSize = Vector2i(612, 792)

class _text:
	func _init(text="", size=12, position=Vector2i(0,0), font="Helvetica") -> void:
		self.text = text
		self.fontSize = size
		self.position = position
		self.font = font
	var text = ""
	var fontSize = 12
	var position = Vector2i(0,0)
	var font = "Helvetica"

class _box:
	func _init(position=Vector2i(0,0), size=Vector2i(0,0), border=Color(0.0,0.0,0.0,1.0), fill=Color(0.0,0.0,0.0,1.0), borderWidth=10) -> void:
		self.size = size
		self.position = position
		self.fill = fill
		self.border = border
		self.borderWidth = borderWidth
	var size = Vector2i(0,0)
	var position = Vector2i(0,0)
	var fill = null
	var border = null
	var borderWidth = 10

class _image:
	func _init(position=Vector2i(0,0), size=Vector2i(0,0), data="", format=Image.FORMAT_RGBA8) -> void:
		self.position = position
		self.size = size
		self.dataStream = data
		self.format = format
	var position = Vector2i(0,0)
	var size = Vector2i(0,0)
	var dataStream = ""
	var format=Image.FORMAT_RGBA8

class _page:
	var text = []
	var boxes = []
	var images = []

class _font:
	func _init(name, path) -> void:
		self.fontName = name
		self.fontPath = path
	var fontName = ""
	var fontPath = ""

func newPDF(t="", c=""):
	_pages = [_page.new()]
	_title = t
	_creator = c
	_fontList = ["Helvetica"]
	_fonts = []

func setTitle(t):
	_title = t

func setCreator(c):
	_creator = c

func newPage() -> bool:
	_pages.append(_page.new())
	return true

func newLabel(pageNum : int, labelPosition, labelText : String, labelSize=12, font="Helvetica") -> bool:
	if labelPosition is Vector2:
		labelPosition = Vector2i(labelPosition)
	if not labelPosition is Vector2i:
		return false
	var label = _text.new(labelText, labelSize, Vector2i(labelPosition.x, _pageSize.y-labelPosition.y), font)
	_pages[pageNum-1].text.append(label)
	return true

func newBox(pageNum : int, boxPosition, boxSize, fill = Color(0.0,0.0,0.0,1.0), border=null, borderWidth : int = 2) -> bool:
	if boxPosition is Vector2:
		boxPosition = Vector2i(boxPosition)
	if not boxPosition is Vector2i:
		return false
	if boxSize is Vector2:
		boxSize = Vector2i(boxSize)
	if not boxSize is Vector2i:
		return false
	if fill != null and not fill is Color:
		return false
	if border != null and not border is Color:
		return false
	var box = _box.new(Vector2i(boxPosition.x, _pageSize.y-boxPosition.y-boxSize.y), boxSize, border, fill, borderWidth)
	_pages[pageNum-1].boxes.append(box)
	return true

func newImage(pageNum : int, imagePosition, baseImage : Image, imageSize = null):
	if baseImage.get_format() != Image.FORMAT_RGB8 and baseImage.get_format() != Image.FORMAT_RGBA8:
		return false
	if imagePosition is Vector2:
		imagePosition = Vector2i(imagePosition)
	if not imagePosition is Vector2i:
		return false
	if imageSize == null:
		imageSize = baseImage.get_size()
	if imageSize is Vector2:
		imageSize = Vector2i(imageSize)
	if not imageSize is Vector2i:
		return false
	baseImage.resize(imageSize.x, imageSize.y)
	var image = _image.new(Vector2i(imagePosition.x, _pageSize.y-imagePosition.y-(imageSize.y)), baseImage.get_size(), baseImage.get_data(), baseImage.get_format())
	_pages[pageNum-1].images.append(image)
	return true

func newFont(fontName : String, fontPath : String) -> bool:
	var font = _font.new(fontName, fontPath)
	_fonts.append(font)
	_fontList.append(fontName)
	return true

func export(path : String) -> bool:
	totalImages = 0
	totalPages = len(_pages)
	var images = []
	for p in _pages:
		for i in p.images:
			images.append(i)
	
	if path == null or path == "" or len(path) < 5 or path.substr(len(path)-4) != ".pdf":
		return false
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	
	_xref = []
	var content = "%PDF-1.6\n"
	
	_xref.append(len(content))				# save byte offset of next object to xref table
	content += _addInfo("Test", "Nolan")		# add new info object
	
	# Add default font
	_xref.append(len(content))
	content += str(len(_xref)) + " 0 obj\n<<\n"
	content += "/Type /Font\n/Subtype /Type1\n/BaseFont /Helvetica"
	content += "\n>>\nendobj\n"
	file.store_string(content)
	var fontOffset = len(content)
	content = ""
	for i in _fonts:
		_xref.append(len(content) + fontOffset)
		fontOffset += _addFont(i, len(content) + fontOffset, file)					# add font object
	
	_xref.append(len(content) + fontOffset)
	content += _addPageTree()			# add page tree
	
	while(len(_pages) > 0):
		_xref.append(len(content) + fontOffset)
		content += _addPage()				# add new page
		_xref.append(len(content) + fontOffset)
		content += _addPageContent()			# add content for new page
	
	# add pages tree and catalog last
	_xref.append(len(content) + fontOffset)
	content += _addCatalog()
	var root = len(_xref)
	
	# add image dictionaries
	file.store_string(content)
	var offset = len(content) + fontOffset
	content = ""
	offset += _addImageDictionary(offset, images, file)
	
	# adds xref and footer information
	_xrefOffset = len(content)+offset
	content += _buildXref()
	content += _buildTrailer(root)
	
	file.store_string(content)
	file.close()
	
	return true

func _addFont(font, contentLength, file : FileAccess):
	var fontWidths = "["
	var f = FontFile.new()
	f.load_dynamic_font(font.fontPath)
	for i in range(256):
		fontWidths += str(f.get_string_size(char(i), 0, -1, 1000).x) + " "
	fontWidths += "]"
	
	var ret = str(len(_xref)) + " 0 obj\n<<\n"
	ret += "/Type /Font\n/Subtype /TrueType\n/BaseFont /" + font.fontName + "\n"
	ret += "/FontDescriptor " + str(len(_xref)+1) + " 0 R\n"
	ret += "/FirstChar 0\n/LastChar 255\n"
	ret += "/Widths " + fontWidths
	ret += "\n>>\nendobj\n"
	
	_xref.append(len(ret) + contentLength)
	ret += str(len(_xref)) + " 0 obj\n<<\n"
	ret += "/Type /FontDescriptor\n/FontName /" + font.fontName + "\n"
	ret += "/FontFile2 " + str(len(_xref)+1) + " 0 R\n"
	ret += "/Flags 6\n/FontBBox [-1000 -1000 1000 1000]\n/MissingWidth 500"
	ret += "\n>>\nendobj\n"
	
	_xref.append(len(ret) + contentLength)
	ret += str(len(_xref)) + " 0 obj\n<<\n"
	var fontStream = FileAccess.get_file_as_bytes(font.fontPath)
	var offset = len(fontStream)
	ret += "/Length " + str(offset) + "\n" + "/Length1 " + str(offset)
	ret += "\n>>\nstream\n"
	file.store_string(ret)
	offset += len(ret)
	for b in fontStream:
		file.store_8(b)
	ret = "\nendstream\nendobj\n"
	file.store_string(ret)
	offset += len(ret)
	
	return offset

func _addInfo(Title=null, Creator=null):
	var ret = str(len(_xref)) + " 0 obj\n<<\n"
	if Title:
		ret += "/Title (" + Title + ")\n"
	if Creator:
		ret += "/Creator (" + Creator + ")\n"
	ret += ">>\nendobj\n"
	return ret

func _buildXref():
	var ret = "xref\n0 "
	ret += str(len(_xref)+1) + "\n"
	ret += "0000000000 65535 f \n"
	for i in _xref:
		ret += _paddedOffset(i) + " 00000 n \n"
	return ret

func _paddedOffset(offset):
	var ret = ""
	for i in range(10-len(str(offset))):
		ret += "0"
	ret += str(offset)
	return ret

func _buildTrailer(root):
	var ret = "trailer\n<<\n"
	ret += "/Size " + str(len(_xref)+1) + "\n"
	ret += "/Root " + str(root) + " 0 R\n"
	ret += "/Info 1 0 R\n"
	ret += ">>\nstartxref\n"
	ret += str(_xrefOffset) + "\n%%EOF"
	return ret

func _addCatalog():
	var ret = str(len(_xref)) + " 0 obj\n<<\n"
	ret += "/Type /Catalog\n"
	ret += "/Pages " + str(3 + ((len(_fontList)-1)*3)) + " 0 R\n"
	ret += ">>\nendobj\n"
	return ret

func _addPageTree():
	var ret = str(len(_xref)) + " 0 obj\n<<\n"
	ret += "/Type /Pages\n"
	ret += "/Count " + str(len(_pages)) + "\n"
	ret += "/Kids ["
	var pageNum = -1
	for i in _pages:
		pageNum += 1
		ret += str(4 + ((len(_fontList)-1)*3) + (pageNum*2)) + " 0 R "
	ret += "]\n"
	ret += ">>\nendobj\n"
	return ret

var totalImages = 0
var totalPages = 0
func _addPage():
	var ret = str(len(_xref)) + " 0 obj\n<<\n"
	ret += "/Type /Page\n"
	ret += "/Parent " + str(3 + ((len(_fontList)-1)*3)) + " 0 R\n"
	ret += "/Resources <</Font <</F0 2 0 R"
	for f in range(len(_fonts)):
		ret += " /F" + str(f+1) + " " + str((f*3)+3) + " 0 R"
	ret += ">> /XObject <<"
	var imageNum = 0
	for i in _pages[0].images:
		imageNum += 1
		ret += "/Im" + str(imageNum) + " " + str(totalImages + ((len(_fontList)-1)*3) + (totalPages*2) + 5) + " 0 R "
		totalImages += 1
	ret += ">>>>\n"
	ret += "/Contents [" + str(len(_xref)+1) + " 0 R]\n"
	ret += ">>\nendobj\n"
	return ret

func _addImageDictionary(contentLength, images, file : FileAccess):
	var offset = 0
	for i in images:
		_xref.append(contentLength + offset)
		var ret = str(len(_xref)) + " 0 obj\n<<\n"
		ret += "/Type /XObject\n/Subtype /Image\n"
		ret += "/Width " + str(i.size.x) + "\n"
		ret += "/Height " + str(i.size.y) + "\n"
		ret += "/ColorSpace /DeviceRGB\n/BitsPerComponent 8\n"
		ret += "/Length " + _getImageLength(len(i.dataStream), i.format) + "\n>>\n"
		ret += "stream\n"
		file.store_string(ret)
		offset += len(ret)
		
		# Add dataStreamAsBytes
		match(i.format):
			Image.FORMAT_RGBA8:
				for j in range(len(i.dataStream)/4):
					if i.dataStream[(j*4)+3] == 0:
						file.store_8(255)
						file.store_8(255)
						file.store_8(255)
					else:
						file.store_8(i.dataStream[j*4])
						file.store_8(i.dataStream[(j*4)+1])
						file.store_8(i.dataStream[(j*4)+2])
					offset += 3
			Image.FORMAT_RGB8:
				for j in i.dataStream:
					file.store_8(j)
					offset += 1
					
		ret = "\nendstream\nendobj\n"
		file.store_string(ret)
		offset += len(ret)
	return offset

func _getImageLength(dataSize, format) -> String:
	match(format):
		Image.FORMAT_RGBA8:
			return str((dataSize/4)*3)
		Image.FORMAT_RGB8:
			return str(dataSize)

	return str(dataSize)

func _addPageContent():
	var textContent = _pages[0].text
	var boxContent = _pages[0].boxes
	var imageContent = _pages[0].images
	var contentStream = ""
	_pages.remove_at(0)
	if len(imageContent) > 0:	# Draw images
		var imageNum = 0
		for i in imageContent:
			imageNum += 1
			contentStream += "q\n"
			contentStream += str(i.size.x) + " 0 0 " + str(i.size.y) + " " + str(i.position.x) + " " + str(i.position.y) + " cm\n"
			contentStream += "/Im" + str(imageNum) + " Do\n"
			contentStream += "Q\n"
	if len(boxContent) > 0:		# Draw boxes
		for x in range(len(boxContent)):
			var i = boxContent[x]
			var rect = str(i.position.x) + " " + str(i.position.y) + " " + str(i.size.x) + " " + str(i.size.y) + " re"
			if i.fill != null:
				contentStream += rect + "\n"
				contentStream += str(i.fill.r) + " " + str(i.fill.g) + " " + str(i.fill.b) + " rg\n"
				contentStream += "f"
				if i.border != null:
					contentStream += "\n"
			if i.border != null:
				contentStream += rect + "\n"
				contentStream += str(i.border.r) + " " + str(i.border.g) + " " + str(i.border.b) + " RG\n"
				contentStream += str(i.borderWidth) + " w\n"
				contentStream += "S"
			if x < len(boxContent)-1:
				contentStream += "\n"
		if len(textContent) > 0:
			contentStream += "\n0.0 0.0 0.0 rg\n"
	if len(textContent) > 0:	# Draw text
		contentStream += "BT\n"
		var lastPos = null
		var lastSize = 0
		for i in textContent:
			contentStream += "/F" + str(_fontList.find(i.font)) + " " + str(i.fontSize) + " Tf\n"
			if lastPos:
				contentStream += str(i.position.x - lastPos.x) + " " + str((i.position.y - i.fontSize) - (lastPos.y - lastSize)) + " Td\n"
			else:
				contentStream += str(i.position.x) + " " + str(i.position.y - i.fontSize) + " Td\n"
			contentStream += "(" + i.text + ") Tj\n"
			lastPos = i.position
			lastSize = i.fontSize
		contentStream += "ET"
	var ret = str(len(_xref)) + " 0 obj\n<<\n"
	ret += "/Length " + str(len(contentStream)) + "\n"
	ret += ">>\nstream\n"
	ret += contentStream + "\n"
	ret += "endstream\nendobj\n"
	return ret
