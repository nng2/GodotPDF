extends Control

func _ready():
	# Create a new PDF document 
	# This just resets the current PDF data
	# This also adds 1 blank page to the PDF
	PDF.newPDF() #PDF.newPDF("New PDF", "Godette")
	PDF.setTitle("New PDF")
	PDF.setCreator("Godette")
	
	# All operations from here on return true or false
	# Use returns to verify functions are running correctly
	
	# Add some text to page 1
	# Format is (page number, position, text, font size)
	# Pages are 612x792 units
	# Font size is optional (Default is 12pt)
	PDF.newLabel(1, Vector2(10,10), "Hello world")
	PDF.newLabel(1, Vector2(10,30), "GodotPDF is awesome!", 20)
	
	# Add a new page
	# The first page is automatically added when initializing the PDF
	PDF.newPage()
	
	# Add some boxes to the new page
	# Format is (page number, position, size, fill color, border color, border size)
	# Colors and border size are optional
	# Setting either fill color or border color to null results in no fill/border
	# Default settings are black fill, no border, border width: 2
	PDF.newBox(2, Vector2(100, 100), Vector2(100, 300))
	PDF.newBox(2, Vector2(200, 400), Vector2(500, 100), Color.GREEN, Color.REBECCA_PURPLE, 10)
	
	# Set the path to export the pdf to
	# The target file MUST be of the .pdf type
	var path = getDesktopPath() + "/GodotPDF.pdf"
	
	# Export the pdf data
	var status = PDF.export(path)
	
	# Print export status
	print("Export successful: " + str(status))

func getDesktopPath():	# gets path to user desktop
	var ret = ""
	var slashes = 0
	for i in OS.get_user_data_dir():
		if i == "/":
			slashes += 1
		if slashes == 3:
			return ret + "/Desktop"
		else:
			ret += i
