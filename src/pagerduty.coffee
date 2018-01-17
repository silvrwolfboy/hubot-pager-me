HttpClient = require 'scoped-http-client'
#Scrolls    = require('../../../lib/scrolls').context({script: 'pagerduty'})
request = require 'request'
qs      = require 'query-string'

pagerDutyApiKey        = process.env.HUBOT_PAGERDUTY_API_KEY
pagerDutySubdomain     = process.env.HUBOT_PAGERDUTY_SUBDOMAIN
pagerDutyBaseUrl       = "https://api.pagerduty.com"
pagerDutyServices      = process.env.HUBOT_PAGERDUTY_SERVICES
pagerNoop              = process.env.HUBOT_PAGERDUTY_NOOP
pagerNoop              = false if pagerNoop is "false" or pagerNoop  is "off"

class PagerDutyError extends Error
module.exports =
  subdomain: pagerDutySubdomain

  http: (path) ->
    HttpClient.create("#{pagerDutyBaseUrl}#{path}")
      .headers(Authorization: "Token token=#{pagerDutyApiKey}", Accept: 'application/json')

  missingEnvironmentForApi: (msg) ->
    missingAnything = false
    unless pagerDutySubdomain?
      msg.send "PagerDuty Subdomain is missing:  Ensure that HUBOT_PAGERDUTY_SUBDOMAIN is set."
      missingAnything |= true
    unless pagerDutyApiKey?
      msg.send "PagerDuty API Key is missing:  Ensure that HUBOT_PAGERDUTY_API_KEY is set."
      missingAnything |= true
    missingAnything

  get: (path, query, cb) ->
    if typeof(query) is 'function'
      cb = query
      query = {}

    if pagerDutyServices? && path.match /\/incidents/
      query['service_ids'] = pagerDutyServices.split ","

    #Scrolls.log('info', {at: 'get/request', path: path, query: query})

    headers = {
      Authorization: "Token token=#{pagerDutyApiKey}", 
      Accept: 'application/vnd.pagerduty+json;version=2'
    }

    queryStr = qs.stringify query, {arrayFormat: 'bracket'}
    path += "?#{queryStr}" if queryStr.length > 0
    url = "#{pagerDutyBaseUrl}#{path}"

    request.get {uri: url, json: true, headers: headers}, (err, res, body) ->
      if err?
        # Scrolls.log('info', {at: 'get/error', path: path, query: query, error: err})
        cb(err)
        return

      #Scrolls.log('info', {at: 'get/response', path: path, query: query, status: res.statusCode, body: body})

      unless res.statusCode is 200
        cb(new PagerDutyError("#{res.statusCode} back from #{path}"))
        return

      cb(null, body)

  put: (path, data, headers, cb) ->
    if pagerNoop
      console.log "Would have PUT #{url}: #{inspect data}"
      return

    headers['Authorization'] = "Token token=#{pagerDutyApiKey}"
    headers['Accept'] = 'application/vnd.pagerduty+json;version=2'

    url = "#{pagerDutyBaseUrl}#{path}"

    request.put {uri: url, json: true, headers: headers, body: data}, (err, res, body) ->
      if err?
        cb(err)
        return

      #Scrolls.log('info', {at: 'put/response', path: path, status: res.statusCode, body: body})

      unless res.statusCode is 200
        cb(new PagerDutyError("#{res.statusCode} back from #{url}"))
        return

      cb(null, body)

  post: (path, data, headers, cb) ->
    if pagerNoop
      console.log "Would have POST #{url}: #{inspect data}"
      return

    headers['Authorization'] = "Token token=#{pagerDutyApiKey}"
    headers['Accept'] = 'application/vnd.pagerduty+json;version=2'

    url = "#{pagerDutyBaseUrl}#{path}"

    request.post {uri: url, json: true, headers: headers, body: data}, (err, res, body) ->
      if err?
        cb(err)
        return

      Scrolls.log('info', {at: 'post/response', path: path, status: res.statusCode, body: body})

      unless res.statusCode is 201
        cb(new PagerDutyError("#{res.statusCode} back from #{url}"))
        return

      cb(null, body)

  delete: (path, cb) ->
    if pagerNoop
      console.log "Would have DELETE #{url}"
      return

    headers = {Authorization: "Token token=#{pagerDutyApiKey}"}
    url = "#{pagerDutyBaseUrl}#{path}"

    request.delete {uri: url, headers: headers}, (err, res) ->
      if err?
        cb(err)
        return

      unless res.statusCode is 200 or res.statusCode is 204
        cb(new PagerDutyError("#{res.statusCode} back from #{url}"), false)
        return

      cb(null, true)

  getIncident: (incident, cb) ->
    @get "/incidents/#{encodeURIComponent incident}", {}, (err, json) ->
      if err?
        cb(err)
        return

      cb(null, json.incident)

  getIncidents: (statuses, cb) ->
    query =
      statuses:  statuses.split ","
      sort_by: "incident_number:asc"
    @get "/incidents", query, (err, json) ->
      if err?
        cb(err)
        return

      cb(null, json.incidents)

  getSchedules: (query, cb) ->
    if typeof(query) is 'function'
      cb = query
      query = {}

    @get "/schedules", query, (err, json) ->
      if err?
        cb(err)
        return

      cb(null, json.schedules)
