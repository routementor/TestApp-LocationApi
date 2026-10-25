# Test suites in detail

[← Back to README](../README.md)

There are two suites. The [README](../README.md#how-the-tests-are-split-and-why) explains why they are
separate; this page lists what each request checks.

All endpoints are `POST` with form-encoded bodies (`[FormParams]`), authenticated with an `X-API-KEY`
header. Almost every endpoint returns **HTTP 200 even on failure**; success or failure is in the JSON body
(`status`, `msg` / `message`, `statusID`, `data`). That is why most assertions are on `jsonpath`, not on
the status code. See [endpoints.md](endpoints.md) for the response formats.

## Read suite: `location-api.hurl`

**Writes:** none. **Safe on production:** yes. **Requests:** 22.

### 1. Authentication (3 requests)

The `REST_Controller` key check runs before any controller code.

| # | Request | Expected |
|---|---|---|
| 1 | `getAllVehicles` with **no** `X-API-KEY` | `403`, `status:false`, `error` starts with `Invalid API Key` |
| 2 | `getAllVehicles` with a **wrong** key | `403`, same error. The server doesn't echo back an invalid key. |
| 3 | `GET` on a POST-only endpoint | `404`, `error: "Unknown method."` |

### 2. Validation errors (10 requests)

Each endpoint is called with a required field missing, and the test checks for CodeIgniter's error message
(`The <label> field is required.`).

Each of these requests sends **at least one** field on purpose. CodeIgniter's `form_validation->run()` returns
`FALSE` without setting any messages when the POST body is completely empty, so an empty request would return
only `"Validation Error "` with nothing useful to assert on.

| Endpoint | Sent | Asserts message contains |
|---|---|---|
| `Cab_GPS_tracking/getAllVehicles` | `companyId` | `The Date Time field is required.` |
| `Cab_GPS_tracking/tracTrip` | `companyId` | `The Trip Id field is required.` |
| `Cab_GPS_tracking/lastGpsPacket` | `type` | `The Trip Id field is required.` |
| `Cab_GPS_tracking/gpsTrackEndPoints` | `companyId` | `The Trip Id field is required.` |
| `Employee_track_cab/trackcab` | `companyId`, `tripId=abc` | `User Id … required` and `Trip Id … only numbers` (the `numeric` rule) |
| `Employee_track_cab/trackcablive` | `companyId`, `tripId` | `The User Id field is required.` |
| `Gps_upload/gps` | `driver_id` | `imei` and `latitude` required (this endpoint uses `message`, not `msg`) |
| `Gps_upload/gps_insert_batch` | `gpsData=<b>[]</b>` | `msg == "Validation error"` (fails the custom `is_html` rule, which rejects HTML tags) |
| `Logs_upload/saveDebugLogs` | `driverId` | `logData` and `deviceId` required |
| `Logs_upload/getLogData` | `driverId` | `The startDate field is required.` |

Validation fails before any model call, so none of these touch the database.

### 3. Normal read calls (9 requests)

What these endpoints return depends on live GPS data: whether the trip ran recently, and whether the device
sent packets. The tests therefore check the **response format**, not the values, and accept both the "found"
and "not found" replies:

| Endpoint | Asserts |
|---|---|
| `getAllVehicles` (`dateTime` = 30 minutes ago) | JSON content type, `status` is a boolean, `msg` ∈ {`Success`, `Initialised`}, `statusID == 0` |
| `tracTrip` | `msg` ∈ {`Success`, `Initialised`} |
| `lastGpsPacket` (no `type`, uses `getLastGPSPacket`) | `msg` ∈ {`Success`, `No data found`} |
| `lastGpsPacket` (`type=details`, uses `getLastGPSPacketDetails`) | `msg` ∈ {`Success`, `No data found`} |
| `getMaxGpsTime` | `msg` ∈ {`Success`, `Initialised`} |
| `gpsTrackEndPoints` with **no** `tripScheduleTime` | `status:false`, `msg: "Initialised"`. With no schedule time, the model returns early without changing anything, so this exercises the endpoint safely. |
| `trackcab` | `msg` ∈ {`Success`, `No data found`}, `statusID` is an integer |
| `trackcablive` | same as `trackcab` |
| `getLogData` (today, for `driver_id`) | `status:true`, `statusID:1`, `data` is an array (it can be empty) |

`Initialised` is the default reply the `Cab_GPS_tracking` methods send when the model finds nothing; they
have no explicit "no data" branch.

> **Getting real data back:** set `trip_id`, `company_id` and `user_id` to a trip that is **running now**.
> If the replies say `Success`, the tracking path is returning real data. With the placeholder `1`s every call
> passes on the "not found" reply, which proves the endpoints respond correctly but not that they find data.

## Write suite: `location-api-write.hurl`

**Writes:** yes. **Safe on production:** only with a dedicated test trip and driver.

**What it inserts each run:**

| Table | Database | Rows | Identifying values |
|---|---|---|---|
| `gpsdata_<Mon>` (for example `gpsdata_Oct`) | `rm_gps_<year>` | 2 | `imei = hurl-test-imei`, `trip_id = {{trip_id}}`, `gpstime = now_epoch` |
| `rm_device_debug` | `rm_location` | 1 | `device_id = hurl-test-device`, `log = "hurl-test-log <now_epoch>"` |

The inserted points are near Bengaluru (`12.9716, 77.5946`). They will show up on that trip's map in the
tracking screens.

### Flow

| # | Request | Expected | What it proves |
|---|---|---|---|
| 1 | `gps_insert_batch` with one packet, `gps_time = now_epoch` | `msg: "1 GPS data rows inserted"`, `statusID:1` | Batch upload works (the same call the driver app makes) |
| 2 | Same packet again | `msg: "no rows inserted"`, `statusID:0` | Duplicates are dropped: a packet must be newer than the trip's latest `gpstime` |
| 3 | `getMaxGpsTime` for the trip | `data` (as an integer) `== now_epoch` | The row was stored, and the read path sees it |
| 4 | `gps` (single packet, legacy endpoint) | `message: "Data Updated to server"` | The single-packet upload works, including the `comments` JSON field |
| 5 | `saveDebugLogs` | `status:true`, `statusID:1` | Log upload works |
| 6 | `getLogData` for today | `data[0].log == "hurl-test-log <now_epoch>"`, `data[0].deviceId == "hurl-test-device"`, `data[0].driverId == driver_id` | The log row was stored. The newest row comes first (`ORDER BY id DESC`). |

Steps 1–3 depend on each other. Every run uses a fresh `now_epoch`, so step 1 inserts again on each run
**unless** the trip already has a packet with a later `gpstime` (for example a live device on the same trip).
In that case step 1 reports `no rows inserted`. Use a trip with no live device.

### Disabled: `gpsTrackEndPoints` update

The real call resets `packet_limit` on the trip's GPS rows and then marks `start_gps_id` / `end_gps_id`. That
changes how the trip's route is drawn and measured, so it is commented out at the bottom of the file. To test
it, uncomment it, set real `gps_id` values from that trip, and use a test trip.

### Cleaning up after a write run

```sql
-- GPS rows (use the right year and month)
DELETE FROM rm_gps_2026.gpsdata_Oct WHERE imei = 'hurl-test-imei';

-- Debug logs
DELETE FROM rm_location.rm_device_debug WHERE device_id = 'hurl-test-device';
```

## Not covered

- **`Keygen/key_genarator`** is a plain `CI_Controller` that inserts an API key. It has no authentication and
  ignores the posted `company_id` (it always uses `2`). It isn't tested, to avoid creating keys; worth
  reviewing separately.
- **`Welcome/index`** is the default CodeIgniter page.
- **Load and performance.** These suites check that the endpoints work, not how they perform under load.

## Reading a failure

Hurl stops at the first failing request in a file. Add `--continue-on-error` to see every failure. A failure
looks like this:

```
error: Assert failure
   --> location-api.hurl:35:0
    |
    | POST {{base_url}}/Cab_GPS_tracking/getAllVehicles
    | ...
 35 | jsonpath "$.error" == "Invalid API Key not-a-real-key"
    |   actual:   string <Invalid API Key >
    |   expected: string <Invalid API Key not-a-real-key>
```

`-->` gives the file and line of the failing assertion; `actual` / `expected` show the difference. To see
the full request and response, add `--very-verbose`.

Common causes:

| Failure | Likely cause |
|---|---|
| Auth tests pass, but every other request gets `403` | `api_key` is wrong or missing from `rm_restapi_access` |
| `HTTP 404` with `Unknown method.` on a POST | Typo in the endpoint name, or the controller wasn't deployed |
| `HTTP 500` / HTML instead of JSON | PHP error on the server. Check `webapp/application/logs/log-<date>.php` |
| Write step 1: `no rows inserted` | The trip already has a GPS packet newer than `now_epoch` (a live device or clock skew). Use another trip. |
| Write step 6: `data[0].log` doesn't match | Another log row was inserted at the same moment, or the server's `created_at` date isn't today in IST |

## Adding a test

1. Read-only? Add it to `location-api.hurl`. Inserts or updates anything? Add it to `location-api-write.hurl`.
2. Use the variables (`{{base_url}}`, `{{api_key}}`, `{{trip_id}}`…) rather than hard-coded values.
3. Assert on the JSON body (`jsonpath "$.status"`, `jsonpath "$.msg"`), since the API returns 200 for most
   errors.
4. Run `./run.sh <suite> --continue-on-error` and update the tables on this page.
