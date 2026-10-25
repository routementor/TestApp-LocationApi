# rm-location REST API — write test suite.
#
# WARNING: these requests INSERT rows (gpsdata_<Mon> in rm_gps_<year>, rm_device_debug in rm_location).
# Run against a local/test server, or against prod only with a dedicated test trip/driver.
#
# Each insert is verified by reading it back. Run with ./run.sh write


# =====================================================================
# GPS batch upload (what the driver app uses) -> read back via getMaxGpsTime
# =====================================================================

POST {{base_url}}/Gps_upload/gps_insert_batch
X-API-KEY: {{api_key}}
[FormParams]
gpsData: [{"user_id":"{{driver_id}}","company_id":"{{company_id}}","trip_id":"{{trip_id}}","tripType":0,"latitude":"12.9716","longitude":"77.5946","accuracy":"10","altitude":"900","gps_time":"{{now_epoch}}","speed":"0","imei":"hurl-test-imei","imsi":"hurl-test-imsi","bearing":"0","provider":"gps","marked":"0"}]
HTTP 200
[Asserts]
jsonpath "$.status" == true
jsonpath "$.msg" == "1 GPS data rows inserted"
jsonpath "$.statusID" == 1

# Same packet again -> deduplicated by gps_time (not newer than the trip's max)
POST {{base_url}}/Gps_upload/gps_insert_batch
X-API-KEY: {{api_key}}
[FormParams]
gpsData: [{"user_id":"{{driver_id}}","company_id":"{{company_id}}","trip_id":"{{trip_id}}","tripType":0,"latitude":"12.9716","longitude":"77.5946","accuracy":"10","altitude":"900","gps_time":"{{now_epoch}}","speed":"0","imei":"hurl-test-imei","imsi":"hurl-test-imsi","bearing":"0","provider":"gps","marked":"0"}]
HTTP 200
[Asserts]
jsonpath "$.status" == true
jsonpath "$.msg" == "no rows inserted"
jsonpath "$.statusID" == 0

POST {{base_url}}/Cab_GPS_tracking/getMaxGpsTime
X-API-KEY: {{api_key}}
[FormParams]
tripId: {{trip_id}}
HTTP 200
[Asserts]
jsonpath "$.status" == true
jsonpath "$.msg" == "Success"
jsonpath "$.data" toInt == {{now_epoch}}


# =====================================================================
# Single GPS packet upload (legacy endpoint)
# =====================================================================

POST {{base_url}}/Gps_upload/gps
X-API-KEY: {{api_key}}
[FormParams]
driver_id: {{driver_id}}
company_id: {{company_id}}
trip_id: {{trip_id}}
imei: hurl-test-imei
imsi: hurl-test-imsi
latitude: 12.9716
longitude: 77.5946
gpstime: {{now_epoch}}
speed: 0
accuracy: 10
altitude: 900
bearing: 0
provider: gps
marked: 0
comments: {"deviceLocationMode":3,"isFakingLocation":false,"netConnectivity":true}
HTTP 200
[Asserts]
jsonpath "$.status" == true
jsonpath "$.message" == "Data Updated to server"


# =====================================================================
# Debug log upload -> read back via getLogData
# =====================================================================

POST {{base_url}}/Logs_upload/saveDebugLogs
X-API-KEY: {{api_key}}
[FormParams]
driverId: {{driver_id}}
deviceId: hurl-test-device
logData: hurl-test-log {{now_epoch}}
HTTP 200
[Asserts]
jsonpath "$.status" == true
jsonpath "$.msg" == "Success"
jsonpath "$.statusID" == 1

POST {{base_url}}/Logs_upload/getLogData
X-API-KEY: {{api_key}}
[FormParams]
driverId: {{driver_id}}
startDate: {{today}}
endDate: {{today}}
HTTP 200
[Asserts]
jsonpath "$.status" == true
jsonpath "$.data" count >= 1
# Newest first (ORDER BY id DESC)
jsonpath "$.data[0].log" == "hurl-test-log {{now_epoch}}"
jsonpath "$.data[0].deviceId" == "hurl-test-device"
jsonpath "$.data[0].driverId" == "{{driver_id}}"


# =====================================================================
# Trip GPS start/end limits — UPDATES packet_limit on the trip's GPS rows.
# Disabled by default; uncomment and set real gps_id values to test.
# =====================================================================

# POST {{base_url}}/Cab_GPS_tracking/gpsTrackEndPoints
# X-API-KEY: {{api_key}}
# [FormParams]
# companyId: {{company_id}}
# tripId: {{trip_id}}
# tripScheduleTime: {{today}} 09:00:00
# start_gps_id: <first gps_id>
# end_gps_id: <last gps_id>
# HTTP 200
# [Asserts]
# jsonpath "$.status" == true
# jsonpath "$.msg" == "Success"
