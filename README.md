# Codecks User Reports for Godot

This is an implementation of the [Codecks User Reports](https://manual.codecks.io/user-reports/) API for Godot.


## Usage

First you need a report token for your Codecks organization, then add `CodecksUserReport.gd` to your Godot project. To create a user report you need to create a `CodecksUserReport` instance to your scene, optionally add files to it and then `.send()` it.

```GDScript
var report:CodecksUserReport

func send_report():
    # create report
    report = CodecksUserReport.new(
        "rt_", # report_token
        "this is a codecks user report", # message
        CodecksUserReport.SEVERITY_HIGH, # severity
        "foo@example.com") # reporter email (optional)
    add_child(report)

    # add file to report
    report.add_file("icon.png", "res://icon.png", "image/png")

    # add signal handler for card creation
    report.connect("card_created", self, "_on_card_created")

    # send it
    report.send()

func _on_card_created(card_id):
	print("codecks card %s created" % card_id)

```

## Example

For an example user report UI you can open this repo as a godot project and look at `main.tscn` as well as `ExampleReportForm.gd`


## TODO
- publish to godot asset library
- unit testing
- support upload of large files by streaming the request body
- improve error handling
- add docstrings
- add types
