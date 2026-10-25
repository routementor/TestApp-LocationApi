# rm-location REST endpoints

[← Back to README](../README.md)

Source: `rm-location/webapp/application/controllers/`. URLs follow CodeIgniter's default routing,
`{base_url}/{Controller}/{method}`. There are no custom routes, and the `_post` suffix of the PHP method is
dropped.

- **Base URL (production):** `http://52.74.152.166/restapi/index.php`
- **Method:** `POST` only. A `GET` returns `404 {"status":false,"error":"Unknown method."}`.
- **Body:** form-encoded (`application/x-www-form-urlencoded`)
- **Auth:** an `X-API-KEY` header, checked against `rm_restapi_access.private_key`. An invalid or missing
  key returns `403 {"status":false,"error":"Invalid API Key "}`.
- **Response:** JSON, HTTP `200` for both success and application errors

Common response format (all endpoints except `Gps_upload/gps`):

```json
{ "status": true, "msg": "Success", "statusID": 0, "data": { } }
```

Required fields are marked with `*`.

## Cab_GPS_tracking

| Endpoint | Parameters | Success | No data / failure |
|---|---|---|---|
| `getAllVehicles` | `companyId`*, `dateTime`* (epoch; packets since then), `tripList` | `Success`, `data` = last location per trip, keyed by trip ID | `Initialised`, `data:null` |
| `tracTrip` | `companyId`*, `tripId`*, `tripType` (default 0), `accuracyLimit` (default 0), `tripScheduleTime`, `tripStartTime` | `Success`, `data` = the trip's GPS track | `Initialised` |
| `lastGpsPacket` | `tripIds`* (comma-separated), `type` (`details` for full packet), `tripType` | `Success`, `data` = last packet per trip | `No data found` |
| `getMaxGpsTime` | `tripId` (not validated) | `Success`, `data` = latest `gpstime` (epoch string) | `Initialised` |
| `gpsTrackEndPoints` ⚠️ writes | `companyId`*, `tripId`*, `tripScheduleTime` (must be after 2019-07-01, otherwise nothing changes), `start_gps_id`, `end_gps_id` | `Success`, `data` = update result | `Initialised` |

## Employee_track_cab

Used by the employee app's "track my cab" screen. All parameters are required and must be **numeric**.

| Endpoint | Parameters | Time window | Success | No data |
|---|---|---|---|---|
| `trackcab` | `companyId`*, `userId`*, `tripId`* | last 30 minutes | `Success`, `statusID:1`, `data` = that trip's last location | `No data found`, `statusID:0` |
| `trackcablive` | `companyId`*, `userId`*, `tripId`* | last 10 minutes | `Success`, `statusID:1`, `data` = live location | `No data found`, `statusID:0` |

## Gps_upload

Used by the driver app to send GPS. Rows go into `rm_gps_<year>.gpsdata_<Mon>` and the table is created if
it doesn't exist yet.

### `gps` ⚠️ writes: single packet (legacy)

Parameters: `driver_id`*, `imei`*, `latitude`*, `longitude`*, `gpstime`* (epoch seconds), `trip_id`,
`company_id`, `imsi`, `speed`, `accuracy`, `altitude`, `bearing`, `provider` (`gps`/`network`/`fused` are
stored as `1`/`0`/`2`), `marked`, `comments` (JSON; the keys `deviceLocationMode`, `isFakingLocation` and
`netConnectivity` are stored as `DLM`, `ML` and `NC`).

This endpoint uses a **different response format**:

```json
{ "status": true,  "message": "Data Updated to server" }
{ "status": false, "message": "Data Updation error" }
{ "status": false, "message": "<p>The imei field is required.</p>..." }
```

### `gps_insert_batch` ⚠️ writes: batch (used by the current driver app)

Parameter: `gpsData`*, a JSON array of packets:

```json
[{ "user_id": "", "company_id": "", "trip_id": "", "tripType": 0,
   "latitude": "", "longitude": "", "accuracy": "", "altitude": "",
   "gps_time": 1792857600, "speed": "", "imei": "", "imsi": "",
   "bearing": "", "provider": "gps", "marked": "0", "comments": "{...}" }]
```

- Packets are inserted 100 at a time.
- A packet is **skipped** unless its `gps_time` is later than the trip's current latest `gpstime`. This drops
  duplicates and stale packets.
- Replies: `"<n> GPS data rows inserted"` (`statusID:1`), `"no rows inserted"` (`statusID:0`), or
  `"Validation error"` with the error text in `data`.

## Logs_upload

Device debug logs, stored in `rm_location.rm_device_debug`.

| Endpoint | Parameters | Reply |
|---|---|---|
| `saveDebugLogs` ⚠️ writes | `logData`*, `driverId`*, `deviceId`* | `Success`, `statusID:1` |
| `getLogData` | `driverId`*, `startDate`*, `endDate`* (`YYYY-MM-DD`, whole days), `uniqueId` (row ID; when set, the other filters are ignored) | `Success`, `statusID:1`, `data` = rows newest first, each `{uniqueId, driverId, deviceId, log, createdDateTime}` (renamed from the `rm_device_debug` columns) |

## Not REST (plain CI_Controller)

| URL | Notes |
|---|---|
| `Keygen/key_genarator` | Inserts a SHA1 API key. **No authentication**, and it ignores the posted `company_id` (always `2`). Not tested. |
| `Welcome/index` | Default CodeIgniter welcome page. |
