@icon("res://addons/codecks_user_reports/cdx__icon.svg")
class_name CodecksUserReport extends Node

## Create Codecks User Reports


const __ASCII_LETTERS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

const SEVERITY_CRITICAL = "critical"
const SEVERITY_HIGH = "high"
const SEVERITY_LOW = "low"
const SEVERITY_NONE = "none"
const SEVERITES = [SEVERITY_CRITICAL, SEVERITY_HIGH, SEVERITY_LOW, SEVERITY_NONE]

enum {NEW, ERROR, CREATING_CARD, UPLOADING_FILES, SUCCESS} # request status

class FileInfo:
	var file_name; var file_path; var content_type; var is_text;

	func _init(file_name_, file_path_, content_type_, is_text_):
		self.file_name = file_name_
		self.file_path = file_path_
		self.content_type = content_type_
		self.is_text = is_text_

class Card:
	var card_id:String
	var report_token:String
	var message:String
	var severity:String
	var email:String
	var status = NEW

signal card_created(card_id)

var _create_card_request = HTTPRequest.new()
var _upload_file_request = HTTPRequest.new()

var _current_file_idx = 0
var _file_infos:Array = []
var _upload_infos:Dictionary


func _init(report_token_, message_, severity_=SEVERITY_NONE, email_=null):
	self.report_token = report_token_
	self.message = message_
	self.severity = severity_
	self.email = email_
	self.status = self.NEW


func add_text_file(file_name, file_path):
	self.add_file(file_name, file_path, "plain/text", true)


func add_binary_file(file_name, file_path):
	self.add_file(file_name, file_path, "application/octet-stream", false)


func add_file(file_name, file_path, content_type, is_text=false):
	if self.status != self.NEW:
		push_error("Unable to add files after sending request")
		return
	self._file_infos.append(FileInfo.new(file_name, file_path, content_type, is_text))


func _upload_next_file():
	self.status = self.UPLOADING_FILES

	if self._current_file_idx >= len(self._file_infos):
		self.status = self.SUCCESS
		emit_signal("card_created", self.card_id)
		return

	var file_info = self._file_infos[self._current_file_idx]
	var upload_info = self._upload_infos[file_info.file_name]

	self._upload_file(
		upload_info["url"],
		upload_info["fields"],
		file_info.file_name,
		file_info.file_path,
		file_info.content_type,
		file_info.is_text)

	self._current_file_idx += 1


func _upload_file(upload_url:String, fields:Dictionary, file_name:String, file_path:String, content_type="application/octet-stream", is_text=false):
	# create multipart boundary
	var boundary = "Boundary"
	for _i in range(16):
		boundary += __ASCII_LETTERS[randi()%len(__ASCII_LETTERS)]

	var prefixed_boundary = ("--%s\r\n" % boundary).to_utf8_buffer()
	var endl = "\r\n".to_utf8_buffer()

	var body = PackedByteArray()
	body.append_array(prefixed_boundary)

	# add fields to request body
	fields["Content-Type"] = content_type
	for field_name in fields.keys():
		var field_value = fields[field_name]
		body.append_array(('Content-Disposition: form-data; name="%s"\r\n\r\n' % field_name).to_utf8_buffer())
		body.append_array(str(field_value).to_utf8_buffer())
		body.append_array(endl)
		body.append_array(prefixed_boundary)

	# add file to request body
	body.append_array(('Content-Disposition: form-data; name="file"; filename="%s"\r\n' % file_name).to_utf8_buffer())
	body.append_array(endl)
	
	var file = FileAccess.open(file_path, FileAccess.READ)	

	if file == null:
		push_error("failed to open %s for reading, error: " % [file_path, FileAccess.get_open_error()])
		self.status = ERROR
		return

	if is_text:
		body.append_array(file.get_as_text().to_utf8_buffer())
	else:
		body.append_array(file.get_buffer(file.get_length()))

	file.close()
	body.append_array(endl)
	body.append_array(("--%s--" % boundary ).to_utf8_buffer())

	if _upload_file_request.get_parent() == null:
		add_child(_upload_file_request)
		_upload_file_request.connect("request_completed", Callable(self, "_upload_file_request_completed"))

	# send request
	var error = _upload_file_request.request_raw(
		upload_url, 
		["Content-Type: multipart/form-data; boundary=%s" % boundary, "Content-Length: %s" % str(body.size())],
		HTTPClient.METHOD_POST, body
	)

	if error != OK:
		self.status = ERROR
		push_error("An error occurred in the HTTP request.")


func _upload_file_request_completed(result, response_code, _headers, body):
	if result != _upload_file_request.RESULT_SUCCESS:
		push_error("upload of file failed with status %s: %s" % [response_code, body])
	self._upload_next_file()


func send():
	if self.status != NEW:
		push_error("Unable to send a CodecksUserReport more than once, please create a new one")
		return
	self.status = CREATING_CARD

	if self.get_parent() == null:
		push_error("Unable to send CodecksUserReport when not added to a scene")
		self.status = ERROR
		return


	add_child(_create_card_request)
	_create_card_request.connect("request_completed", Callable(self, "_create_card_request_completed"))

	var _severity = self.severity
	var _file_names = []
	if _severity == SEVERITY_NONE or len(_severity) == 0:
		_severity = null

	for file_info in self._file_infos:
		_file_names.append(file_info.file_name)

	var body = {
		"content": self.message,
		"severity": _severity,
		"fileNames": _file_names,
		}

	if self.email != null and len(self.email) > 0 and self.email.count("@") >= 1:
		body["userEmail"] = self.email

	var json_body = JSON.stringify(body)	
	var error = _create_card_request.request(
		"https://api.codecks.io/user-report/v1/create-report?token=%s" % self.report_token,
		["Content-Type: application/json"], 
		HTTPClient.METHOD_POST, 
		json_body
		)
	if error != OK:
		self.status = ERROR
		push_error("An error occurred in the HTTP request: %s" % json_body)


func _create_card_request_completed(_result, _response_code, _headers, body):
	var response_text = body.get_string_from_utf8()
	var test_json_conv = JSON.new()
	test_json_conv.parse(response_text)
	var parsed_response:Dictionary = test_json_conv.get_data()
	if typeof(parsed_response) != TYPE_DICTIONARY or not parsed_response.get("ok", false):
		push_error("unexpected response from api.codecks.io: %s" % response_text)
		self.status = self.ERROR
		return

	self.card_id = parsed_response["cardId"]
	for uploadInfo in parsed_response["uploadUrls"]:
		self._upload_infos[uploadInfo["fileName"]] = uploadInfo

	if len(self._file_infos) == 0:
		self.status = self.SUCCESS
		emit_signal("card_created", self.card_id)
		return

	if len(self._file_infos) == len(self._upload_infos):
		self._upload_next_file()
		return

	self.status = self.ERROR
	push_error("codecks api didn't return the right number of upload urls, skipping upload")
