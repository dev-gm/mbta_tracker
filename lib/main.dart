import 'package:flutter/material.dart';
import "dart:core";
import "global_info.dart";
import "stop_selection.dart";


void main() {
	runApp(const MainApp());
}

class MainApp extends StatefulWidget {
	const MainApp({super.key});

	@override
	State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
	GlobalInfo globalInfo = GlobalInfo();

	@override
	Widget build(BuildContext context) {
		return MaterialApp(
			title: "MBTA Tracker",
			theme: ThemeData(useMaterial3: true),
			home: StopSelection(global: globalInfo),
		);
	}
}

