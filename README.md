# TestApp-LocationApi

Automated API tests for the **rm-location** server (`rm-location/webapp`), the CodeIgniter 3 REST service
the driver and employee apps use to upload and track GPS. The tests are written in [Hurl](https://hurl.dev),
a plain-text format for HTTP requests and assertions.

## Quick start

```bash
# 1. Install hurl (Ubuntu / WSL); other platforms are in docs/installing-hurl.md
curl -LO https://github.com/Orange-OpenSource/hurl/releases/download/7.1.0/hurl_7.1.0_amd64.deb
sudo apt install ./hurl_7.1.0_amd64.deb
hurl --version

# 2. Create your local config, then set the server, API key and test IDs
cp location.env.example location.env
$EDITOR location.env

# 3. Run the safe, read-only suite
./run.sh
```

## Installing Hurl

You need **Hurl 7.x** (the suite was written and verified with 7.1.0).

| Platform | Command |
|---|---|
| Ubuntu / Debian / WSL | `curl -LO https://github.com/Orange-OpenSource/hurl/releases/download/7.1.0/hurl_7.1.0_amd64.deb && sudo apt install ./hurl_7.1.0_amd64.deb` |
| macOS | `brew install hurl` |
| Windows | `winget install hurl` (or `choco install hurl` / `scoop install hurl`) |
| Any (Node) | `npm install -g @orangeopensource/hurl` |

Then check it works with `hurl --version`. See [docs/installing-hurl.md](docs/installing-hurl.md) for other
options (Cargo, Docker, Arch, Fedora) and troubleshooting.

## Configuration: `location.env`

Every suite reads its variables from `location.env`. That file holds real credentials, so it is
**git-ignored**. The repository has [`location.env.example`](location.env.example) instead, with placeholders:

```bash
cp location.env.example location.env    # then fill in api_key, the IDs and the FMS login
```

| Variable | Meaning |
|---|---|
| `base_url` | Location server, including `index.php`. The default is production, the same URL the driver app uses (`Api.LOCATION_SERVER`). |
| `api_key` | Value sent in the `X-API-KEY` header. It must exist in `rm_restapi_access.private_key`. |
| `company_id`, `trip_id`, `user_id`, `driver_id` | IDs used in the requests. The defaults are placeholder `1`s; use real IDs (ideally a test company, trip and driver) for meaningful results. |
| `fms_email`, `fms_password` | FMS web app login, used only by `basic.hurl`. |
| `error_format` | `long` (default) or `short`. A `run.sh` setting, passed to hurl as `--error-format`; see [Running the tests](#running-the-tests). |

`run.sh` also sets three time variables on every run: `now_epoch`, `since_epoch` (30 minutes ago) and
`today` (an IST date).

> `location.env` holds a real API key and password in plain text. Keep it out of git (`.gitignore` already
> does this) and out of tickets. When you add a variable, add it to `location.env.example` too, with a
> placeholder value.

## How the tests are split, and why

| Suite | File | Touches the DB? | Safe on production? |
|---|---|---|---|
| **read** | [`location-api.hurl`](location-api.hurl) | Reads only | ✅ Yes |
| **write** | [`location-api-write.hurl`](location-api-write.hurl) | **Inserts rows** | ⚠️ Only with a dedicated test trip and driver |

The server serves live production traffic, and several endpoints insert data: GPS packets go into
`gpsdata_<Mon>`, which drives live cab tracking and trip reports, and debug logs go into `rm_device_debug`.
Keeping everything that writes in its own file means:

- **The read suite can run anytime, anywhere.** You can run it against production as a health check, after a
  deploy, or in a cron job, without leaving data behind. It covers authentication, input validation on all
  11 endpoints, and the response format of every read endpoint.
- **The write suite is a deliberate choice.** It proves the full round trip (upload, then read back what was
  stored), so it has to create real rows. Run it against a local or staging server, or against production
  only with IDs set aside for testing.
- **Destructive calls stay off by default.** The real `gpsTrackEndPoints` update rewrites a trip's start/end
  GPS markers, so it is commented out in the write suite.

Details of what each request checks are in [docs/test-suites.md](docs/test-suites.md).

## Running the tests

`run.sh` wraps `hurl --test` with the variables file and the time variables:

```bash
./run.sh            # read-only suite (the default)
./run.sh read       # same as above
./run.sh write      # write suite only: inserts GPS and log rows
./run.sh all        # read suite, then write suite
```

When a request fails, `run.sh` prints the **full HTTP response** (status, headers and body) under the
error, which shows PHP errors and other non-JSON replies directly. This comes from the `error_format` setting
in `location.env`, which is passed to hurl as `--error-format`:

```ini
error_format=long    # full response for failing requests (default)
error_format=short   # one-line assert errors only
```

To change it for a single run without editing the file:

```bash
ERROR_FORMAT=short ./run.sh
```

> With `long`, hurl also prints a ready-to-run `curl` command for each failure, **including the API key**.
> Take care when pasting test output into chats or tickets.

Any extra arguments are passed straight to hurl:

```bash
# Point at a local server instead of production
./run.sh write --variable base_url=http://localhost/rm-location/webapp/index.php

# Use a real trip for this run only
./run.sh read --variable trip_id=123456 --variable company_id=7

# Report every failing request instead of stopping at the first one in each file
./run.sh all --continue-on-error

# Show request and response details while debugging
./run.sh read --very-verbose

# Write an HTML report to ./report
./run.sh all --report-html report
```

A passing run ends like this:

```
Success location-api.hurl (22 request(s) in 5209 ms)
Executed requests: 22 (4.2/s)
Succeeded files:   1 (100.0%)
```

`run.sh` exits with a non-zero code when any assertion fails, so it can gate a CI job or a deploy script.

### Running the write suite

The write suite **inserts real rows** on the server in `base_url`. Each run adds:

| Table | Rows | How to recognise them |
|---|---|---|
| `rm_gps_<year>.gpsdata_<Mon>` | 2 | `imei = 'hurl-test-imei'`, `trip_id` = your `trip_id` |
| `rm_location.rm_device_debug` | 1 | `device_id = 'hurl-test-device'` |

**1. Set test IDs in `location.env`.** Use a company, trip and driver set aside for testing, never a live
customer's trip:

```ini
company_id=5        # test company (testadmin@routementor.com)
trip_id=82812433    # a trip with NO live device sending GPS
driver_id=17216     # test driver
user_id=10325       # test employee (used only by the read suite)
```

The trip must not have a driver app sending GPS while the suite runs. The upload only accepts a packet that
is newer than the trip's latest `gpstime`, so a live device on the same trip makes step 1 fail with
`no rows inserted`.

**2. Run it:**

```bash
./run.sh write                         # write suite only
./run.sh all                           # read suite first, then write suite
./run.sh write --continue-on-error     # show every failing step, not just the first
```

**3. Check the result.** A passing run executes 6 requests:

```
Success location-api-write.hurl (6 request(s) in ... ms)
```

| Step | Request | Passes when |
|---|---|---|
| 1 | `Gps_upload/gps_insert_batch`, one packet | `1 GPS data rows inserted`; the month's table is created if it is missing |
| 2 | The same packet again | `no rows inserted` (duplicates are dropped) |
| 3 | `Cab_GPS_tracking/getMaxGpsTime` | Returns the `gps_time` sent in step 1, so the row was stored |
| 4 | `Gps_upload/gps`, single packet | `Data Updated to server` |
| 5 | `Logs_upload/saveDebugLogs` | `Success` |
| 6 | `Logs_upload/getLogData`, today | The newest log row is the one sent in step 5 |

The suite reads back each row it writes, so a pass means the data was stored, not just accepted. You can also
check in MySQL:

```sql
SELECT gps_id, trip_id, gpstime, imei FROM rm_gps_2026.gpsdata_Oct
 WHERE imei = 'hurl-test-imei' ORDER BY gps_id DESC LIMIT 5;
SELECT id, driver_id, device_id, created_at, log FROM rm_location.rm_device_debug
 WHERE device_id = 'hurl-test-device' ORDER BY id DESC LIMIT 5;
```

**4. Clean up** (change the year and month to match the run):

```sql
DELETE FROM rm_gps_2026.gpsdata_Oct WHERE imei = 'hurl-test-imei';
DELETE FROM rm_location.rm_device_debug WHERE device_id = 'hurl-test-device';
```

**Re-running:** every run uses the current time as `gps_time`, so you can run the suite repeatedly. Wait
at least a second between runs, because two runs in the same second send the same timestamp and step 1
then reports `no rows inserted`.

**Testing a local server** without touching the shared one:

```bash
./run.sh write --variable base_url=http://localhost/rm-location/webapp/index.php
```

If a step fails, see [docs/test-suites.md](docs/test-suites.md#write-suite-location-api-writehurl) for what
each step checks and the common causes.

### Running hurl directly

If you'd rather not use the script, this is what `./run.sh read` does:

```bash
now=$(date +%s)
hurl --test --variables-file location.env \
  --variable now_epoch=$now \
  --variable since_epoch=$((now - 1800)) \
  --variable today=$(TZ=Asia/Kolkata date +%F) \
  location-api.hurl
```

## Documentation

- [docs/installing-hurl.md](docs/installing-hurl.md): installation on every platform, and troubleshooting
- [docs/test-suites.md](docs/test-suites.md): request-by-request coverage of both suites, and how to read failures
- [docs/endpoints.md](docs/endpoints.md): reference for the rm-location REST endpoints (parameters and responses)

## Other files

- `basic.hurl`: an earlier scratch test against the main FMS web app login (`routementor.com/fms`). It is
  unrelated to the location API and not run by `run.sh`. It reads the login from `fms_email` /
  `fms_password` in `location.env`:
  `hurl --test --variables-file location.env basic.hurl`
