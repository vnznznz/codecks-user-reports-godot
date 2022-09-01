extends Panel

export var report_token:String


onready var message_text = $MarginContainer/VBoxContainer/MessageEdit
onready var email_text = $MarginContainer/VBoxContainer/EMailEdit
onready var severity_select = $MarginContainer/VBoxContainer/SeveritySelect

func _ready():
	for severity in CodecksUserReport.SEVERITES:
		severity_select.add_item(severity)
	severity_select.select(len(CodecksUserReport.SEVERITES) -1 )

func _on_SendReportButton_pressed():
	var message = message_text.text
	var email = email_text.text
	var severity = CodecksUserReport.SEVERITES[severity_select.get_selected_id()]

	var report = CodecksUserReport.new(report_token, message, severity, email)
	report.add_file("icon.png", "res://icon.png", "image/png")
	report.add_file("test.txt", "res://test.txt", "plain/text", true)
	add_child(report)
	report.send()
