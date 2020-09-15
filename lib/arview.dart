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
      "cHBWfDc6QxkcDQvFW1sBVMjOFDMPh0hKO6Z3k5Yu8azOvr6puhiwR7pM17vhturOmBdgnPkkoQ6uVYjtxWnYU2o+sTTQrbCXpy1Kfzyk/1LE6UR4zuCtFRdf43FmMHNsfRr/+cwFy+y6oFUmoPWvkhGKg2mTZaqwZGiZ3gQLwHBTYWx0ZWRfXwoxiZybKkOd/4kF2++bu9aD1ZhBB7pAq3uaaufwJBRgG3flCMR0K9bAwFW0d5x1VGbzAeckY8YywVraffMXf2xm+VSg+GNaqwaIJ469K4Sc7kZVBJyloUOvZTNR36mHw56fH9x4GvDaZEsduvx3NprXP/PPPwUVtEK0lECMXzdM0+igVsE3AbeVdanlrQ9oPAlB7wx57vgfirvjAr5K/aa5t89dlA5WLkTVHCC73/3HmrS1pgYVTtBKoE09809LnQ2km6O7ZrIIe7AXfMzWD8Dh1KoFwPdTkSPYsfEQoFw/v4lm0Q0iaMl0VoUcxUm4ueOd+ulHn7KB5so6BVBp7lNptSF8nSz9GcLawc22ArHmqJr6Zer3FB4l00D0t1QI2MlRmUg3/1MboFnB5mMs4albPsHg5ZYt+vCmo5vgsYrxX276bXZ9a0somtVa+Xb8FDCgssjNbymCXbd7+u266x9Ac+jG70zo2ydCfnpdeZmVlApzig1lluqnVULxhQJJwfHtEAv8amiTujPpQ4gDE+tSWie3ppK0RSsW8WH7jNGtVtIFvYhUTaIvSfpVGX1NgzUHoOKEbqgqySGvI3C4eiT9q+FRgROaj9IZqdrhZKu/hAQg+v66OZ5YvBEL5vB1u/AGNZiZc7GK+NPw2WS7Qe2jU2csv00jVB9YHn4ittXTMz5rHlxIOy0=";
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
