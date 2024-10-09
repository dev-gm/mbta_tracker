import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import "dart:convert";
import "package:intl/intl.dart";

class StopSchedule extends StatefulWidget {
	const StopSchedule({
		super.key, required this.directionDest, required this.stopId, required this.routePatternIds
	});

	final String directionDest;
	final String stopId;
	final List<String> routePatternIds;

	@override
	State<StopSchedule> createState() => _StopScheduleState();
}

class _StopScheduleState extends State<StopSchedule> {
	// routePatternId, stopId
	(List<String>, String) scheduleLastUpdate = ([], "");
	List<(String, DateTime)> predictions = [];
	List<String> tripIds = [];
	bool retrievedTripIds = false;

	Future<void> update() async {
		await retrieveSchedule();
	}

	Future<void> retrieveSchedule() async {
		if (widget.routePatternIds.isEmpty) {
			return;
		}
		if (scheduleLastUpdate == (widget.routePatternIds, widget.stopId)) {
			return;
		}
		var response = await http.get(Uri.parse(
			"https://api-v3.mbta.com/predictions?include=schedule&filter%5Broute_pattern%5D=${widget.routePatternIds.join(",")}"
		));
		if (response.statusCode != 200) {
			return;
		}
		var now = DateTime.now();
		var body = jsonDecode(response.body);
		var rawPredictions = body["data"];
		predictions.clear();
		predictionLoop:
		for (var rawPrediction in rawPredictions) {
			if (rawPrediction["relationships"]["stop"]["data"]["id"] != widget.stopId) {
				continue predictionLoop;
			}
			var vehicleId = rawPrediction["id"];
			var arrivalTime = rawPrediction["attributes"]["arrival_time"];
			var departureTime = rawPrediction["attributes"]["departure_time"];
			var time = arrivalTime ?? departureTime;
			if (time == null) {
				continue predictionLoop;
			}
			var datetime = DateTime.parse(time);
			if (datetime.isBefore(now)) {
				continue predictionLoop;
			}
			predictions.add((vehicleId, datetime));
		}
		var rawSchedule = body["included"];
		scheduleLoop:
		for (var vehicle in rawSchedule) {
			var stopId = vehicle["relationships"]["stop"]["data"]["id"];
			if (stopId != widget.stopId) {
				continue scheduleLoop;
			}
			var vehicleId = vehicle["id"];
			var arrivalTime = vehicle["attributes"]["arrival_time"];
			var departureTime = vehicle["attributes"]["departure_time"];
			var time = arrivalTime ?? departureTime;
			if (time == null) {
				continue scheduleLoop;
			}
			var datetime = DateTime.parse(time);
			if (datetime.isBefore(now)) {
				continue scheduleLoop;
			}
			//var patternId = vehicle["relationships"]["route_pattern"]["data"]["id"];
			//var schedule = global.schedules.putIfAbsent((patternId, stopId), () => []);
			//schedule.add((vehicleId, datetime));
			predictions.add((vehicleId, datetime));
		}
		predictions.sort((a, b) => a.$2.compareTo(b.$2));
		scheduleLastUpdate = (widget.routePatternIds, widget.stopId);
	}

	Widget buildSchedule() {
		List<(Duration, dynamic)> durationData = [];
		List<Widget> body = [];
		var now = DateTime.now();
		for (var vehicle in predictions) {
			var msAway = vehicle.$2.millisecondsSinceEpoch - now.millisecondsSinceEpoch;
			var duration = Duration(milliseconds: msAway);
			durationData.add((duration, vehicle));
		}
		durationData.sort((a, b) => a.$1.compareTo(b.$1));
		for (var (duration, vehicle) in durationData) {
			var minAway = duration.inMinutes % 60;
			var hrsAway = duration.inHours;
			String leftInfo;
			if (hrsAway == 0) {
				leftInfo = "$minAway min";
			} else if (hrsAway == 1) {
				leftInfo = "$hrsAway hr $minAway min";
			} else {
				var local = vehicle.$2.toLocal();
				leftInfo = DateFormat.jm().format(local);
			}
			body.add(Row(
				children: [
					Text(widget.directionDest, style: const TextStyle(fontSize: 20)),
					const Spacer(),
					Text(leftInfo, style: const TextStyle(fontSize: 20)),
				],
			));
		}
		return Column(
			children: body,
		);
	}

	@override
	Widget build(BuildContext context) {
		return FutureBuilder(
			future: update(),
			builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
				if (snapshot.connectionState == ConnectionState.waiting) {
					return Center(
						child: Container(
							padding: const EdgeInsets.all(20),
							child: const CircularProgressIndicator(),
						),
					);
				}
				if (snapshot.hasError) {
					return Text(snapshot.error.toString());
				}
				return buildSchedule();
			},
		);
	}
}
