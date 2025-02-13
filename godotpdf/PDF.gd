extends Control

var _xref = []
var _xrefOffset = 0
var _pages = []
var _title = ""
var _creator = ""
var _pageSize = Vector2i(612, 792)

class _text:
	func _init(text="", size=12, position=Vector2i(0,0)) -> void:
		self.text = text
		self.fontSize = size
		self.position = position
	var text = ""
	var fontSize = 12
	var position = Vector2i(0,0)

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

class _page:
	var text = []
	var boxes = []

func newPDF(t="", c=""):
	_pages = [_page.new()]
	_title = t
	_creator = c

func setTitle(t):
	_title = t

func setCreator(c):
	_creator = c

func newPage() -> bool:
	_pages.append(_page.new())
	return true

func newLabel(pageNum : int, labelPosition, labelText : String, labelSize=12) -> bool:
	if labelPosition is Vector2:
		labelPosition = Vector2i(labelPosition)
	if not labelPosition is Vector2i:
		return false
	var label = _text.new(labelText, labelSize, Vector2i(labelPosition.x, _pageSize.y-labelPosition.y))
	_pages[pageNum-1].text.append(label)
	return true

func newBox(pageNum : int, boxPosition, boxSize, fill : Color = Color(0.0,0.0,0.0,1.0), border=null, borderWidth : int = 2) -> bool:
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

func export(path : String) -> bool:
	if path == null or path == "" or len(path) < 5 or path.substr(len(path)-4) != ".pdf":
		return false
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	
	_xref = []
	var content = "%PDF-1.6\n"
	
	_xref.append(len(content))				# save byte offset of next object to xref table
	content += _addInfo("Test", "Nolan")		# add new info object
	
	_xref.append(len(content))
	content += _addPageTree()			# add page tree
	
	while(len(_pages) > 0):
		_xref.append(len(content))
		content += _addPage()				# add new page
		_xref.append(len(content))
		content += _addPageContent()			# add content for new page
	
	# add pages tree and catalog last
	_xref.append(len(content))
	content += _addCatalog()
	
	# adds xref and footer information
	_xrefOffset = len(content)
	content += _buildXref()
	content += _buildTrailer()
	
	file.store_string(content)
	file.close()
	
	return true

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

func _buildTrailer():
	var ret = "trailer\n<<\n"
	ret += "/Size " + str(len(_xref)+1) + "\n"
	ret += "/Root " + str(len(_xref)) + " 0 R\n"
	ret += "/Info 1 0 R\n"
	ret += ">>\nstartxref\n"
	ret += str(_xrefOffset) + "\n%%EOF"
	return ret

func _addCatalog():
	var ret = str(len(_xref)) + " 0 obj\n<<\n"
	ret += "/Type /Catalog\n"
	ret += "/Pages 2 0 R\n"
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
		ret += str(3 + (pageNum*2)) + " 0 R "
	ret += "]\n"
	ret += ">>\nendobj\n"
	return ret

func _addPage():
	var ret = str(len(_xref)) + " 0 obj\n<<\n"
	ret += "/Type /Page\n"
	ret += "/Parent 2 0 R\n"
	ret += "/Contents [" + str(len(_xref)+1) + " 0 R]\n"
	ret += ">>\nendobj>>\n"
	return ret

func _addPageContent():
	var textContent = _pages[0].text
	var boxContent = _pages[0].boxes
	var contentStream = ""
	_pages.remove_at(0)
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
		for i in textContent:
			contentStream += str(i.fontSize) + " Tf\n"
			if lastPos:
				contentStream += str(i.position.x - lastPos.x) + " " + str(i.position.y - lastPos.y - i.fontSize) + " Td\n"
			else:
				contentStream += str(i.position.x) + " " + str(i.position.y - i.fontSize) + " Td\n"
			contentStream += "(" + i.text + ") Tj\n"
			lastPos = i.position
		contentStream += "ET"
	var ret = str(len(_xref)) + " 0 obj\n<<\n"
	ret += "/Length " + str(len(contentStream)) + "\n"
	ret += ">>\nstream\n"
	ret += contentStream + "\n"
	ret += "endstream\nendobj\n"
	return ret
