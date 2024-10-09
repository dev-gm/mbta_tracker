class GlobalInfo {
	GlobalInfo();

	bool retrievedRoutes = false;

	// <routeName, routeId>
	Map<String, String> routeIds = {"": ""};
	// <routeId, routeName>
	Map<String, String> routeNames = {"": ""};
	// <routeName>
	List<String> routes = [""];

	// directionId is just index of directions
	// <routeId, <(directionName, directionDest)>>
	Map<String, (List<String>, List<String>)> directions = {"": ([""], [""])};

	// <routePatternId, tripId>
	Map<String, String> routePatternCanonicalTripIds = {"": ""};
	Map<String, String> routePatternIds = {"": ""};
	Map<String, String> routePatternNames = {"": ""};
	// <(routeId, directionId), <routePatternName>>
	Map<(String, int), List<String>> routePatterns = {("", 0): [""]};

	// <stopName, stopId>
	Map<String, String> stopIds = {"": ""};
	// <stopId, stopName>
	Map<String, String> stopNames = {"": ""};
	// <<routePatternId>, <stopName>>
	Map<List<String>, List<String>> stops = {[]: []};

	// <(routePatternId, stopId), <(vehicleId, datetimeScheduled)>>
	Map<(String, String), List<(String, DateTime)>> schedules = {("", ""): []};
}
