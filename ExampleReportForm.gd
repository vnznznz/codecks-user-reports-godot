extends Panel

@onready var token_edit = $MarginContainer/VBoxContainer/TokenEdit
@onready var message_edit = $MarginContainer/VBoxContainer/MessageEdit
@onready var email_edit = $MarginContainer/VBoxContainer/EMailEdit
@onready var severity_select = $MarginContainer/VBoxContainer/SeveritySelect
@onready var testTxtButton = $MarginContainer/VBoxContainer/FileTestTxtButton
@onready var iconPngButton = $MarginContainer/VBoxContainer/FileIconPngButton

var report:CodecksUserReport = null

func _ready():
	for severity in CodecksUserReport.SEVERITES:
		severity_select.add_item(severity)
	severity_select.select(len(CodecksUserReport.SEVERITES) -1 )


func _on_SendReportButton_pressed():
	var report_token = token_edit.text
	var message = message_edit.text
	var email = email_edit.text
	var severity = CodecksUserReport.SEVERITES[severity_select.get_selected_id()]

	if len(report_token) < 10:
		alert("Please enter a report token", "Error")
		token_edit.grab_focus()
		token_edit.select_all()

	# cleanup old reports
	if report != null:
		report.queue_free()
	
	report = CodecksUserReport.new(report_token, message, severity, email)
	report.connect("card_created", Callable(self, "_on_card_created"))

	if testTxtButton.pressed:
		report.add_text_file("test.txt", "res://test.txt")
	if iconPngButton.pressed:
		report.add_file("icon.png", "res://icon.png", "image/png")

	add_child(report)
	report.send()

# taken from https://gamedev.stackexchange.com/a/178770/21937
func alert(text: String, title: String='Message') -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = text
	dialog.title = title
	dialog.connect('modal_closed', Callable(dialog, 'queue_free'))
	add_child(dialog)
	dialog.popup_centered()

func _on_card_created(card_id):
	print("codecks card %s created" % card_id)
