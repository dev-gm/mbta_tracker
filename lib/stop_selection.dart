import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import "dart:convert";
import "global_info.dart";
import "stop_schedule.dart";

class StopSelection extends StatefulWidget {
	const StopSelection({super.key, required this.global});

	final GlobalInfo global;

	@override
	State<StopSelection> createState() => _StopSelectionState();
}

class _StopSelectionState extends State<StopSelection> {
	String routeName = "";
	int directionId = 0;
	List<String> routePatternNames = [];
	String stopName = "";
	// routePatternId
	List<String> stopLastUpdated = [];

	Widget makeDropdown(String val, Iterable<String> list, ValueChanged<String?> onChanged) {
		if (!list.contains(val)) {
			return makeDropdown("", [""], (_) {});
		}
		return Row(
			mainAxisAlignment: MainAxisAlignment.center,
			children: [
				Expanded(
					child: DropdownButton<String>(
						isExpanded: true,
						value: val,
						items: list.map<DropdownMenuItem<String>>((el) {
							return DropdownMenuItem<String>(
								value: el,
								child: Center(child: Text(el,
									style: const TextStyle(fontSize: 20),
									overflow: TextOverflow.ellipsis,
								)),
							);
						}).toList(),
						onChanged: onChanged,
					),
				),
			],
		);
	}

	Widget makeExpandedCheckbox(List<String> selected, List<String> list, void Function(String, bool) onChanged) {
		if (selected.isNotEmpty && !selected.every((el) => list.contains(el))) {
			return makeExpandedCheckbox([], [""], (a, b) {});
		}
		list.sort();
		return ListView.builder(
			shrinkWrap: true,
			itemCount: list.length,
			itemBuilder: (context, index) => CheckboxListTile(
				value: selected.contains(list[index]),
				onChanged: (newVal) {
					if (newVal == null) {
						return;
					}
					onChanged(list[index], newVal);
				},
				title: Text(list[index], style: const TextStyle(fontSize: 20)),
			)
		);
	}

	Future<void> update() async {
		await retrieveRoutes();
		await retrieveStops();
		setState(() {});
	}

	Future<void> retrieveRoutes() async {
		if (widget.global.retrievedRoutes) {
			return;
		}
		var response = await http.get(Uri.parse("https://api-v3.mbta.com/routes?include=route_patterns"));
		if (response.statusCode != 200) {
			return;
		}
		widget.global.routes = [];
		var rawRoutes = jsonDecode(response.body)["data"];
		for (var rawRoute in rawRoutes) {
			var routeId = rawRoute["id"];
			var attr = rawRoute["attributes"];
			var longName = attr["long_name"];
			var shortName = attr["short_name"];
			String routeName;
			if (shortName == "") {
				routeName = longName;
			} else {
				routeName = "$shortName | $longName";
			}
			widget.global.routeIds.putIfAbsent(routeName, () => routeId);
			widget.global.routeNames.putIfAbsent(routeId, () => routeName);
			widget.global.routes.add(routeName);
			var routeDir = widget.global.directions.putIfAbsent(routeId, () => ([], []));
			var dirNames = attr["direction_names"];
			var dirDests = attr["direction_destinations"];
			for (var i = 0; i < 2; i++) {
				routeDir.$1.add(dirNames[i]);
				routeDir.$2.add(dirDests[i]);
			}
		}
		routeName = widget.global.routes[0];
		directionId = 0;
		var rawPatterns = jsonDecode(response.body)["included"];
		for (var rawPattern in rawPatterns) {
			var patternId = rawPattern["id"];
			var relationships = rawPattern["relationships"];
			var patternRouteId = relationships["route"]["data"]["id"];
			var attr = rawPattern["attributes"];
			var patternDirId = attr["direction_id"];
			var patternName = attr["name"];
			var pattern = widget.global.routePatterns.putIfAbsent((patternRouteId, patternDirId), () => []);
			pattern.add(patternName);
			widget.global.routePatternIds.putIfAbsent(patternName, () => patternId);
			widget.global.routePatternNames.putIfAbsent(patternId, () => patternName);
			String tripId = relationships["representative_trip"]["data"]["id"];
			widget.global.routePatternCanonicalTripIds.putIfAbsent(patternId, () => tripId);
		}
		widget.global.retrievedRoutes = true;
	}

	Future<void> retrieveStops() async {
		if (!widget.global.retrievedRoutes) {
			return;
		}
		var patternNames = routePatternNames.isNotEmpty ? routePatternNames
		: widget.global.routePatterns[(widget.global.routeIds[routeName], directionId)]!;
		var patternIds = patternNames.map((name) => widget.global.routePatternIds[name]!).toList();
		if (patternIds == stopLastUpdated) {
			stopName = widget.global.stops[patternIds]![0];
			stopLastUpdated = patternIds;
		}
		var response = await http.get(Uri.parse(
			"https://api-v3.mbta.com/trips?include=stops,route_pattern&filter%5Broute_pattern%5D=${patternIds.join(",")}"
		));
		if (response.statusCode != 200) {
			return;
		}
		var currStops = widget.global.stops.putIfAbsent(patternIds, () => []);
		currStops.clear();
		var rawStops = jsonDecode(response.body)["included"];
		for (var rawStop in rawStops) {
			var stopName = rawStop["attributes"]["name"];
			var stopId = rawStop["id"];
			widget.global.stopIds.putIfAbsent(stopName, () => stopId);
			widget.global.stopNames.putIfAbsent(stopId, () => stopName);
			currStops.add(stopName);
		}
		stopName = currStops[0];
	}

	@override
	void initState() {
		super.initState();
		update();
	}

	@override
	Widget build(BuildContext context) {
		var routeId = widget.global.routeIds[routeName]!;
		var directionDest = widget.global.directions[routeId]!.$2[directionId];
		List<String> routePatternIds = [];
		List<String> selectedStops = [];
		if (routePatternNames.isNotEmpty && widget.global.retrievedRoutes) {
			routePatternIds = routePatternNames.map((patternName) => widget.global.routePatternIds[patternName]!).toList();
			selectedStops = widget.global.stops.putIfAbsent(routePatternIds, () => []);
		}
		if (selectedStops.isEmpty) {
			selectedStops = [""];
		}
		var body = [
			makeDropdown(routeName, widget.global.routes, (String? newVal) async {
				if (newVal == null) return;
				routeName = newVal;
				routeId = widget.global.routeIds[routeName]!;
				directionId = 0;
				routePatternNames = widget.global.routePatterns[(routeId, directionId)]!;
				await update();
			}),
			makeDropdown(widget.global.directions[routeId]!.$1[directionId], widget.global.directions[routeId]!.$1, (String? newVal) async {
				if (newVal == null) return;
				directionId = widget.global.directions[routeId]!.$1.indexOf(newVal);
				routePatternNames = widget.global.routePatterns[(routeId, directionId)]!;
				await update();
			}),
			makeExpandedCheckbox(routePatternNames, widget.global.routePatterns[(routeId, directionId)]!, (String patternName, bool state) async {
				if (!state) {
					routePatternNames.remove(patternName);
				} else if (!routePatternNames.contains(patternName)) {
					routePatternNames.add(patternName);
				}
				await update();
			}),
			makeDropdown(stopName, selectedStops, (String? newVal) async {
				if (newVal == null) return;
				stopName = newVal;
				await update();
				},
			),
			StopSchedule(routePatternIds: routePatternIds, directionDest: directionDest, stopId: widget.global.stopIds[stopName]!),
		];
		return Scaffold(
			appBar: AppBar(title: const Center(child: Text("MBTA Tracker"))),
			body: RefreshIndicator(
				onRefresh: update,
				child: ListView.builder(
					padding: const EdgeInsets.all(8),
					itemCount: body.length,
					itemBuilder: (context, i) => body[i],
				),
			),
		);
	}
}
