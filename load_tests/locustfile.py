"""
locustfile for simulating API requests

to run, make sure LOCUST_API_KEY is in your env and contains
a valid API key for the API environment being load tested.

example command:
$ LOCUST_API_KEY="myapikey" locust --host="https://my-api-env.mbtace.com"

for reference, prod handles ~250 requests/second with 3 instances
"""
import os
from locust import HttpUser, task, between
from random import choice, randint


class ApiUser(HttpUser):

    wait_time = between(0.5, 3)

    # TODO is there a better way to pass this in?
    api_key = os.environ["LOCUST_API_KEY"]
    headers = {"x-api-key": api_key}

    # reusable data
    green_line_routes = ["Green-B", "Green-C", "Green-D", "Green-E"]
    light_rail_routes = green_line_routes + ["Mattapan"]
    heavy_rail_routes = ["Red", "Orange", "Blue"]
    subway_routes = heavy_rail_routes + light_rail_routes
    key_bus_routes = [
        "1",
        "15",
        "22",
        "23",
        "28",
        "32",
        "39",
        "57",
        "66",
        "71",
        "73",
        "77",
        "111",
        "116",
        "117",
    ]
    solari_screen_stations = [
        # forest hills
        "10642",
        # nubian square
        "place-dudly",
        # sullivan square upper busway
        ["29001", "29002", "29003", "29004", "29005", "29006"],
        # ashmont
        "334",
        # wonderland
        "15795",
        # ruggles lower busway
        ["17862", "17863"],
    ]
    eink_screen_stations = [
        # washington square (Green-B)
        "place-bcnwa",
        # museum of fine arts (Green-E)
        "place-mfa",
    ]

    # helper function to construct JSONAPI queries
    def api_request(
        self, endpoint, name=None, fields=None, filters=None, include=None, sort=None
    ):

        params = {}
        if filters is not None:
            for fltr, fltr_val in filters.items():
                if isinstance(fltr_val, list):
                    fltr_val = ",".join(fltr_val)
                params[f"filter[{fltr}]"] = fltr_val

        if fields is not None:
            for field, field_val in fields.items():
                if isinstance(field_val, list):
                    field_val = ",".join(field_val)
                params[f"fields[{field}]"] = field_val

        if include is not None:
            if isinstance(include, list):
                include = ",".join(include)
            params["include"] = include

        if sort is not None:
            params["sort"] = sort

        return self.client.get(endpoint, name=name, headers=self.headers, params=params)

    # simple requests (performed more frequently)
    @task(10)
    def get_portal(self):
        self.api_request("/")

    @task(10)
    def get_alerts(self):
        self.api_request("/alerts", name="/alerts", include="facilities")

    @task(10)
    def get_vehicles(self):
        self.api_request("/vehicles")

    @task(5)
    def get_all_subway_routes(self):
        self.api_request(
            "/stops",
            name="/stops (all subway routes)",
            filters={"route": self.subway_routes},
            include="route",
        )

    # route schedules

    @task(len(subway_routes))
    def get_subway_schedules(self):
        # pick a random route to query for
        route = choice(self.subway_routes)
        self.api_request(
            "/schedules", name="/schedules (subway routes)", filters={"route": route}
        )

    @task(len(key_bus_routes))
    def get_key_bus_route_schedules(self):
        # pick a random route to query for
        route = choice(self.key_bus_routes)
        self.api_request(
            "/schedules", name="/schedules (key bus routes)", filters={"route": route}
        )

    @task(len(green_line_routes))
    def get_green_line_trips(self):
        # pick a random route to query for
        route = choice(self.green_line_routes)
        self.api_request(
            "/trips",
            name="/trips (Green Line)",
            filters={"route": route},
            include=["route", "vehicle", "service", "predictions"],
        )

    # station schedules/predictions

    @task(len(solari_screen_stations))
    def get_station_predictions(self):
        # pick a random route to query for
        stop = choice(self.solari_screen_stations)
        self.api_request(
            "/predictions",
            name="/predictions (Solari screens)",
            filters={"stop": stop},
            include=["route", "stop", "trip", "trip.stops", "vehicle", "alerts"],
            sort="departure_time",
        )

    @task(2 * len(eink_screen_stations))
    def get_station_schedules(self):
        direction = randint(0, 1)
        self.api_request(
            "/schedules",
            name="/schedules (e-ink screens)",
            filters={"direction_id": direction, "stop": self.eink_screen_stations},
            include=["route", "stop", "trip"],
            sort="departure_time",
        )

    @task
    def get_back_bay_schedules(self):
        self.api_request(
            "/schedules",
            name="/schedules (Commuter Rail @ Back Bay)",
            filters={
                "route": ["CR-Worcester", "CR-Franklin", "CR-Needham", "CR-Providence"],
                "stop": "place-bbsta",
            },
            include=["route", "stop", "trip"],
            sort="departure_time",
        )

    @task
    def get_commuter_rail_station_predictions(self):
        self.api_request(
            "/predictions",
            name="/predictions (Commuter Rail stations)",
            filters={
                "route_type": 2,
                "stop": ["place-sstat", "place-north", "place-bbsta"],
            },
            include=["trip", "schedule", "stop"],
        )

    # route schedules/predictions

    @task(len(green_line_routes))
    def get_green_line_schedules_with_predictions(self):
        # pick a random route to query for
        route = choice(self.green_line_routes)
        self.api_request(
            "/schedules",
            name="/schedules (Green Line branches)",
            filters={"route": route},
            include=["prediction", "stop"],
        )

    @task(len(heavy_rail_routes))
    def get_heavy_rail_schedules_with_predictions(self):
        # pick a random route to query for
        route = choice(self.heavy_rail_routes)
        self.api_request(
            "/schedules",
            name="/schedules (heavy rail)",
            filters={"route": route},
            include=["stop", "trip", "prediction"],
            sort="arrival_time",
        )

    @task(len(heavy_rail_routes))
    def get_heavy_rail_predictions_with_alerts(self):
        # pick a random route to query for
        route = choice(self.heavy_rail_routes)
        self.api_request(
            "/predictions",
            name="/predictions (heavy rail)",
            filters={"route": route},
            include=["stop", "trip", "route", "vehicle", "alerts"],
        )

    @task
    def get_all_green_line_predictions_with_alerts(self):
        self.api_request(
            "/predictions",
            name="/predictions (Green Line)",
            filters={"route": self.green_line_routes},
            include=["stop", "trip", "route", "vehicle", "alerts"],
        )

    @task
    def get_all_subway_predictions_with_schedules(self):
        self.api_request(
            "/predictions",
            name="/predictions (all subway routes)",
            filters={"route": self.subway_routes},
            include=["vehicle", "schedule", "stop", "route", "trip"],
        )
