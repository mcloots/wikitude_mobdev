import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:wakelock/wakelock.dart';
import 'applicationModelPois.dart';
import 'poi.dart';

import 'sample.dart';

import 'package:path_provider/path_provider.dart';

import 'package:augmented_reality_plugin_wikitude/architect_widget.dart';
import 'package:augmented_reality_plugin_wikitude/wikitude_plugin.dart';
import 'package:augmented_reality_plugin_wikitude/wikitude_response.dart';
import 'package:wikitude_flutter_app/poiDetails.dart';

class ArViewState extends State<ArViewWidget> with WidgetsBindingObserver {
  ArchitectWidget architectWidget;
  String wikitudeTrialLicenseKey =
      "XbdczeTvK3yU3HTp8wfj6Pkp661TDSfjbmPNJ8WYdU6X0mwPQNIGqOoSjZ+IvFE/ryrVJb21Jm6ewSJ1W75zjOPL89H4je5betgWuuBBo/8GhUUnr1Oe4V1zgfRH0zvvU9jCQBXrAPqk60QnuyTkuMjPoY9J7ZlxsTP/dpk1e1hTYWx0ZWRfX/Y9416tXXonzYMZoQnT1maprLJ5c5QCiZLcejCJXBMcNJLcyPn7t9ekOWCrwhVX77lqeWR/yU92FUcrlrwVEuTscBVDs7CgHbuXuJ3NGyrUS1qCmFkfFbNGnDYv0m0Wgu7FCfW0EI6Rf43NFR0UbUzpe5lJxE8xTxGbqkmqdRJUc9JM9Vl669oxksq0sT8NqUc0Foo9VTksVRW3T0fSB0jVBoa+cyUY9v4Gfk6H6tHZEoUhpsz9FVNDjYsXyGm0gjtwtS9piPhi1qha1wAi7PkYauiTsvBpkFN7jaxA54ME1POYlbI0+5zQvSboXQ1gT5+ZQZqBevBbcd5MVONOtRg/iQMtTnGMyc/o+SepG4CYi0h/O3Li1/7mpyWa8AOo5xVinmgdDJjN+4uYaCm22j4AeiDGK8ejltxIL0G5SKhAtjkoq73+L9Hp1RFzs6oLGLEfGHr+4XMnQRyYXQCM74QIZsuLwL3Yr9DgHtNDlQn75OtSowOFVr5EcT+RUH8TuP2sSaSMU6NkkDPeZmGIvaeQl4IWBEeTQ1dAIGw0KXSZtplxyiVTdeWNZes3yPoxo7ByfF4SH7tflntfQxnZf2ky2AdHD1p8jEjvbfCmSExfTroUFwq89xUSeVjmc2nPDeSB7OkmRdRW3YGi2LmrdA27FTzSArxS06GK2EO3I7uS4aDZw67Np2M=";
  Sample sample;
  String loadPath = "";

  ArViewState(Sample sample) {
    this.sample = sample;
    if (sample.path.contains("http://") || sample.path.contains("https://")) {
      loadPath = sample.path;
    } else {
      loadPath = "samples/" + sample.path;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    architectWidget = new ArchitectWidget(
      onArchitectWidgetCreated: onArchitectWidgetCreated,
      licenseKey: wikitudeTrialLicenseKey,
      startupConfiguration: sample.startupConfiguration,
      features: sample.requiredFeatures,
    );

    Wakelock.enable();
  }

  @override
  void dispose() {
    if (this.architectWidget != null) {
      this.architectWidget.pause();
      this.architectWidget.destroy();
    }
    WidgetsBinding.instance.removeObserver(this);

    Wakelock.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        if (this.architectWidget != null) {
          this.architectWidget.pause();
        }
        break;
      case AppLifecycleState.resumed:
        if (this.architectWidget != null) {
          this.architectWidget.resume();
        }
        break;

      default:
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(sample.name)),
      body: Container(
          decoration: BoxDecoration(color: Colors.black),
          child: architectWidget),
    );
  }

  Future<void> onArchitectWidgetCreated() async {
    this.architectWidget.load(loadPath, onLoadSuccess, onLoadFailed);
    this.architectWidget.resume();

    if (sample.requiredExtensions != null &&
        sample.requiredExtensions.contains("application_model_pois")) {
      ApplicationModelPois applicationModelPois = new ApplicationModelPois();
      List<Poi> pois = await applicationModelPois.prepareApplicationDataModel();
      this.architectWidget.callJavascript(
          "World.loadPoisFromJsonData(" + jsonEncode(pois) + ");");
    }

    if (sample.requiredExtensions != null &&
        (sample.requiredExtensions.contains("screenshot") ||
            sample.requiredExtensions.contains("save_load_instant_target") ||
            sample.requiredExtensions.contains("native_detail"))) {
      this.architectWidget.setJSONObjectReceivedCallback(onJSONObjectReceived);
    }
  }

  Future<void> onJSONObjectReceived(Map<String, dynamic> jsonObject) async {
    if (jsonObject["action"] != null) {
      switch (jsonObject["action"]) {
        case "capture_screen":
          captureScreen();
          break;
        case "present_poi_details":
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => PoiDetailsWidget(
                    id: jsonObject["id"],
                    title: jsonObject["title"],
                    description: jsonObject["description"])),
          );
          break;
        case "save_current_instant_target":
          final fileDirectory = await getApplicationDocumentsDirectory();
          final filePath = fileDirectory.path;
          final file = File('$filePath/SavedAugmentations.json');
          file.writeAsString(jsonObject["augmentations"]);
          this.architectWidget.callJavascript(
              "World.saveCurrentInstantTargetToUrl(\"" +
                  filePath +
                  "/SavedInstantTarget.wto" +
                  "\");");
          break;
        case "load_existing_instant_target":
          final fileDirectory = await getApplicationDocumentsDirectory();
          final filePath = fileDirectory.path;
          final file = File('$filePath/SavedAugmentations.json');
          String augmentations;
          try {
            augmentations = await file.readAsString();
          } catch (e) {
            augmentations = "null";
          }
          this.architectWidget.callJavascript(
              "World.loadExistingInstantTargetFromUrl(\"" +
                  filePath +
                  "/SavedInstantTarget.wto" +
                  "\"," +
                  augmentations +
                  ");");
          break;
      }
    }
  }

  Future<void> captureScreen() async {
    WikitudeResponse captureScreenResponse =
        await this.architectWidget.captureScreen(true, "");
    if (captureScreenResponse.success) {
      showSingleButtonDialog(
          "Success", "Image saved in: " + captureScreenResponse.message, "OK");
    } else {
      if (captureScreenResponse.message.contains("permission")) {
        showDialogOpenAppSettings("Error", captureScreenResponse.message);
      } else {
        showSingleButtonDialog("Error", captureScreenResponse.message, "Ok");
      }
    }
  }

  void showSingleButtonDialog(
      String title, String content, final String buttonText) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: <Widget>[
              FlatButton(
                child: Text(buttonText),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }

  void showDialogOpenAppSettings(String title, String content) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: <Widget>[
              FlatButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              FlatButton(
                child: const Text('Open settings'),
                onPressed: () {
                  Navigator.of(context).pop();
                  WikitudePlugin.openAppSettings();
                },
              )
            ],
          );
        });
  }

  Future<void> onLoadSuccess() async {}

  Future<void> onLoadFailed(String error) async {
    showSingleButtonDialog("Failed to load Architect World", error, "Ok");
  }
}

class ArViewWidget extends StatefulWidget {
  final Sample sample;

  ArViewWidget({
    Key key,
    @required this.sample,
  });

  @override
  ArViewState createState() => new ArViewState(sample);
}
