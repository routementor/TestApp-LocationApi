# rm-location REST API — read-only / safe test suite.
#
# Nothing in this file writes to the database, so it is safe to run against production:
#   - auth checks (missing / wrong X-API-KEY)
#   - validation-error checks for every endpoint (validation fails before any model call)
#   - happy-path calls for the read endpoints (asserts response shape, since data depends on live trips)
#
# Run with ./run.sh (or see README.md).


# =====================================================================
# Auth
# =====================================================================

# No API key -> 403
POST {{base_url}}/Cab_GPS_tracking/getAllVehicles
[FormParams]
companyId: {{company_id}}
dateTime: {{now_epoch}}
HTTP 403
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.status" == false
jsonpath "$.error" startsWith "Invalid API Key"

# Wrong API key -> 403
POST {{base_url}}/Cab_GPS_tracking/getAllVehicles
X-API-KEY: not-a-real-key
[FormParams]
companyId: {{company_id}}
dateTime: {{now_epoch}}
HTTP 403
[Asserts]
jsonpath "$.status" == false
jsonpath "$.error" startsWith "Invalid API Key"

# GET on a POST-only endpoint -> 404 "Unknown method."
GET {{base_url}}/Cab_GPS_tracking/getAllVehicles
X-API-KEY: {{api_key}}
HTTP 404
[Asserts]
jsonpath "$.status" == false
jsonpath "$.error" == "Unknown method."


# =====================================================================
# Validation errors (one field sent so CI form_validation populates the errors)
# =====================================================================

POST {{base_url}}/Cab_GPS_tracking/getAllVehicles
X-API-KEY: {{api_key}}
[FormParams]
companyId: {{company_id}}
HTTP 200
[Asserts]
jsonpath "$.status" == false
jsonpath "$.msg" contains "The Date Time field is required."
jsonpath "$.data" == null

POST {{base_url}}/Cab_GPS_tracking/tracTrip
X-API-KEY: {{api_key}}
[FormParams]
companyId: {{company_id}}
HTTP 200
[Asserts]
jsonpath "$.status" == false
jsonpath "$.msg" contains "The Trip Id field is required."

POST {{base_url}}/Cab_GPS_tracking/lastGpsPacket
X-API-KEY: {{api_key}}
[FormParams]
type: details
HTTP 200
[Asserts]
jsonpath "$.status" == false
jsonpath "$.msg" contains "The Trip Id field is required."

POST {{base_url}}/Cab_GPS_tracking/gpsTrackEndPoints
X-API-KEY: {{api_key}}
[FormParams]
companyId: {{company_id}}
HTTP 200
[Asserts]
jsonpath "$.status" == false
jsonpath "$.msg" contains "The Trip Id field is required."

POST {{base_url}}/Employee_track_cab/trackcab
X-API-KEY: {{api_key}}
[FormParams]
companyId: {{company_id}}
tripId: abc
HTTP 200
[Asserts]
jsonpath "$.status" == false
jsonpath "$.msg" contains "The User Id field is required."
jsonpath "$.msg" contains "The Trip Id field must contain only numbers."

POST {{base_url}}/Employee_track_cab/trackcablive
X-API-KEY: {{api_key}}
[FormParams]
companyId: {{company_id}}
tripId: {{trip_id}}
HTTP 200
[Asserts]
jsonpath "$.status" == false
jsonpath "$.msg" contains "The User Id field is required."

POST {{base_url}}/Gps_upload/gps
X-API-KEY: {{api_key}}
[FormParams]
driver_id: {{driver_id}}
HTTP 200
[Asserts]
jsonpath "$.status" == false
jsonpath "$.message" contains "The imei field is required."
jsonpath "$.message" contains "The latitude field is required."

POST {{base_url}}/Gps_upload/gps_insert_batch
X-API-KEY: {{api_key}}
[FormParams]
gpsData: <b>[]</b>
HTTP 200
[Asserts]
jsonpath "$.status" == false
jsonpath "$.msg" == "Validation error"

POST {{base_url}}/Logs_upload/saveDebugLogs
X-API-KEY: {{api_key}}
[FormParams]
driverId: {{driver_id}}
HTTP 200
[Asserts]
jsonpath "$.status" == false
jsonpath "$.msg" contains "The logData field is required."
jsonpath "$.msg" contains "The deviceId field is required."

POST {{base_url}}/Logs_upload/getLogData
X-API-KEY: {{api_key}}
[FormParams]
driverId: {{driver_id}}
HTTP 200
[Asserts]
jsonpath "$.status" == false
jsonpath "$.msg" contains "The startDate field is required."


# =====================================================================
# Happy path — read endpoints
# These return "no data" responses when the trip/company has no recent GPS, so the
# asserts check the response contract rather than specific values.
# =====================================================================

POST {{base_url}}/Cab_GPS_tracking/getAllVehicles
X-API-KEY: {{api_key}}
[FormParams]
companyId: {{company_id}}
dateTime: {{since_epoch}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.status" isBoolean
jsonpath "$.msg" matches "^(Success|Initialised)$"
jsonpath "$.statusID" == 0

POST {{base_url}}/Cab_GPS_tracking/tracTrip
X-API-KEY: {{api_key}}
[FormParams]
companyId: {{company_id}}
tripId: {{trip_id}}
tripType: 0
accuracyLimit: 100
HTTP 200
[Asserts]
jsonpath "$.status" isBoolean
jsonpath "$.msg" matches "^(Success|Initialised)$"
jsonpath "$.statusID" == 0

# type != details -> getLastGPSPacket
POST {{base_url}}/Cab_GPS_tracking/lastGpsPacket
X-API-KEY: {{api_key}}
[FormParams]
tripIds: {{trip_id}}
tripType: 0
HTTP 200
[Asserts]
jsonpath "$.status" isBoolean
jsonpath "$.msg" matches "^(Success|No data found)$"

# type = details -> getLastGPSPacketDetails
POST {{base_url}}/Cab_GPS_tracking/lastGpsPacket
X-API-KEY: {{api_key}}
[FormParams]
tripIds: {{trip_id}}
type: details
tripType: 0
HTTP 200
[Asserts]
jsonpath "$.status" isBoolean
jsonpath "$.msg" matches "^(Success|No data found)$"

POST {{base_url}}/Cab_GPS_tracking/getMaxGpsTime
X-API-KEY: {{api_key}}
[FormParams]
tripId: {{trip_id}}
HTTP 200
[Asserts]
jsonpath "$.status" isBoolean
jsonpath "$.msg" matches "^(Success|Initialised)$"

# No tripScheduleTime -> model returns 0 before touching the DB (safe no-op).
# The real update path is in location-api-write.hurl.
POST {{base_url}}/Cab_GPS_tracking/gpsTrackEndPoints
X-API-KEY: {{api_key}}
[FormParams]
companyId: {{company_id}}
tripId: {{trip_id}}
HTTP 200
[Asserts]
jsonpath "$.status" == false
jsonpath "$.msg" == "Initialised"

POST {{base_url}}/Employee_track_cab/trackcab
X-API-KEY: {{api_key}}
[FormParams]
companyId: {{company_id}}
userId: {{user_id}}
tripId: {{trip_id}}
HTTP 200
[Asserts]
jsonpath "$.status" isBoolean
jsonpath "$.msg" matches "^(Success|No data found)$"
jsonpath "$.statusID" isInteger

POST {{base_url}}/Employee_track_cab/trackcablive
X-API-KEY: {{api_key}}
[FormParams]
companyId: {{company_id}}
userId: {{user_id}}
tripId: {{trip_id}}
HTTP 200
[Asserts]
jsonpath "$.status" isBoolean
jsonpath "$.msg" matches "^(Success|No data found)$"
jsonpath "$.statusID" isInteger

POST {{base_url}}/Logs_upload/getLogData
X-API-KEY: {{api_key}}
[FormParams]
driverId: {{driver_id}}
startDate: {{today}}
endDate: {{today}}
HTTP 200
[Asserts]
jsonpath "$.status" == true
jsonpath "$.msg" == "Success"
jsonpath "$.statusID" == 1
jsonpath "$.data" isCollection
