HttpClient = require 'scoped-http-client'

pagerDutyUserId        = process.env.HUBOT_PAGERDUTY_USER_ID
pagerDutyApiKey        = process.env.HUBOT_PAGERDUTY_API_KEY
pagerDutySubdomain     = process.env.HUBOT_PAGERDUTY_SUBDOMAIN
pagerDutyBaseUrl       = "https://#{pagerDutySubdomain}.pagerduty.com/api/v1"
pagerDutyServiceApiKey = process.env.HUBOT_PAGERDUTY_SERVICE_API_KEY
pagerDutyServices      = process.env.HUBOT_PAGERDUTY_SERVICES
pagerRoom              = process.env.HUBOT_PAGERDUTY_ROOM
# Webhook listener endpoint. Set it to whatever URL you want, and make sure it matches your pagerduty service settings
pagerEndpoint          = process.env.HUBOT_PAGERDUTY_ENDPOINT || "/hook"
pagerNoop              = process.env.HUBOT_PAGERDUTY_NOOP
pagerNoop               = false if pagerNoop is "false" or pagerNoop  is "off"

module.exports = (robot) ->

  class PagerDutyError extends Error

  http = (path) ->
    auth =
    HttpClient.create("#{pagerDutyBaseUrl}#{path}")
      .headers(Authorization: "Token token=#{pagerDutyApiKey}", Accept: 'application/json')

  pagerDutyGet = (msg, url, query, cb) ->
    if pagerDutyServices? && url.match /\/incidents/
      query['service'] = pagerDutyServices

    http(url)
      .query(query)
      .get() (err, res, body) ->
        if err?
          cb(err)
          return
        json_body = null
        switch res.statusCode
          when 200 then json_body = JSON.parse(body)
          else
            cb(new PagerDutyError("#{res.statusCode} back from #{url}"))

        cb null, json_body

  missingEnvironmentForApi = (msg) ->
    missingAnything = false
    unless pagerDutySubdomain?
      msg.send "PagerDuty Subdomain is missing:  Ensure that HUBOT_PAGERDUTY_SUBDOMAIN is set."
      missingAnything |= true
    unless pagerDutyApiKey?
      msg.send "PagerDuty API Key is missing:  Ensure that HUBOT_PAGERDUTY_API_KEY is set."
      missingAnything |= true
    missingAnything

  pagerDutyPut = (msg, url, data, cb) ->
    if pagerNoop
      console.log "Would have PUT #{url}: #{inspect data}"
      return

    json = JSON.stringify(data)
    http(url)
      .header("content-type","application/json")
      .header("content-length",json.length)
      .put(json) (err, res, body) ->
        if err?
          if cb.length is 1
            robot.emit 'error', err, msg
          else
            callback(err)
          return

        json_body = null
        switch res.statusCode
          when 200 then json_body = JSON.parse(body)
          else
            if cb.length is 1
              console.log res.statusCode
              console.log body
              json_body = null
            else
              return cb(new PagerDutyError("#{res.statusCode} back from #{url}"))
        if cb.length is 1
          cb json_body
        else
          cb null, json_body

  pagerDutyPost = (msg, url, data, cb) ->
    if pagerNoop
      console.log "Would have POST #{url}: #{inspect data}"
      return

    json = JSON.stringify(data)
    http(url)
      .header("content-type","application/json")
      .header("content-length",json.length)
      .post(json) (err, res, body) ->
        if err?
          return cb(err)

        json_body = null
        switch res.statusCode
          when 201 then json_body = JSON.parse(body)
          else
            return cb(new PagerDutyError("#{res.statusCode} back from #{url}"))
        cb null, json_body

  pagerDutyDelete = (msg, url, cb) ->
    if pagerNoop
      console.log "Would have DELETE #{url}"
      return

    auth = "Token token=#{pagerDutyApiKey}"
    http(url)
      .header("content-length",0)
      .delete() (err, res, body) ->
        if err?
          return cb(err)
        json_body = null
        switch res.statusCode
          when 204, 200
            value = true
          else
            console.log res.statusCode
            console.log body
            value = false
        cb null, value

  getIncident = (msg, incident, cb) ->
    pagerDutyGet msg, "/incidents/#{encodeURIComponent incident}", {}, (err, json) ->
      if err?
        cb(err)
        return

      cb(null, json)

  getIncidents = (msg, status, cb) ->
    query =
      status:  status
      sort_by: "incident_number:asc"
    pagerduty.get msg, "/incidents", query, (err, json) ->
      if err?
        cb(err)
        return
      cb(null, json.incidents)

  pagerduty =
    missingEnvironmentForApi: missingEnvironmentForApi
    get: pagerDutyGet
    put: pagerDutyPut
    post: pagerDutyPost
    delete: pagerDutyDelete
    getIncident: getIncident
    getIncidents: getIncidents
  return pagerduty
