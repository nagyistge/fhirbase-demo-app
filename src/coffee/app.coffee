window.CodeMirror = require('../../bower_components/codemirror/lib/codemirror.js')
require('../../bower_components/angular/angular.js')
require('../../bower_components/angular-route/angular-route.js')
require('../../bower_components/angular-sanitize/angular-sanitize.js')
require('../../bower_components/angular-animate/angular-animate.js')
require('../../bower_components/angular-scroll/angular-scroll.js')
require('../../bower_components/angular-cookies/angular-cookies.js')
require('../../bower_components/angular-ui-codemirror/ui-codemirror.js')
require('../../bower_components/codemirror/mode/sql/sql.js')

require('../../bower_components/codemirror/lib/codemirror.css')
require('../../bower_components/codemirror/theme/tomorrow-night-eighties.css')
require('../../bower_components/codemirror/theme/xq-light.css')
require('../../bower_components/codemirror/addon/hint/show-hint.css')
require('../../bower_components/codemirror/addon/hint/show-hint.js')
require('../../bower_components/codemirror/addon/hint/sql-hint.js')
#hint = require('./sql-hint.js')
#hint(window.CodeMirror)

require('file?name=index.html!../index.html')
require('file?name=fhir.json!../fhir.json')
require('../less/app.less')

app = require('./module')

require('./views')

sitemap = require('./sitemap')


app.config ($routeProvider) ->
  rp = $routeProvider
    .when '/',
      templateUrl: '/views/index.html'
      controller: 'IndexController'
  rp.otherwise
    templateUrl: '/views/404.html'

app.run ($rootScope, $window, $location, $http)->


SELECT_PROCS = """
SELECT
'fhir.' || routine_name || '(' ||
  coalesce(( select string_agg(x.parameter_name || ' ' || x.data_type, ', ') from
    information_schema.parameters  x
    where routines.specific_name=x.specific_name
  ), '')
  || ')' as title
  from information_schema.routines
  where routine_schema = 'fhir'
  order by routine_name
"""

SELECT_TBLS = """
  SELECT tablename as title
  FROM pg_catalog.pg_tables where schemaname = 'public'
  AND tablename not like '%_history'
  order by tablename;
"""
CREATE_SNIPS = """
 insert into snippets (sql, title) values
    ('SELECT resource_type, logical_id, version_id, content from patient ORDER BY updated DESC limit 10;\n-- show last 10 patients', '1. show patients table'),
    ('SELECT fhir.create(''{"resourceType":"Patient", "name": [{"given": ["John"]}]}'');\n-- create patient with given name ''John'' ', '2. create patient'),
    ('SELECT fhir.read(''Patient'', (SELECT logical_id FROM patient ORDER BY updated DESC LIMIT 1));\n-- show created patient', '3. read last created patient'),
    ('SELECT fhir.update( jsonbext.merge( fhir.read(''Patient'', (SELECT logical_id FROM patient ORDER BY updated DESC LIMIT 1) ), ''{"name":[{"given":"Bruno"}]}'' ) );\n-- returns updated patient version', '4. rename last created patient'),
    ('SELECT fhir.history(''Patient'', (SELECT logical_id FROM patient ORDER BY updated DESC LIMIT 1));\n-- returns history bundle', '5. show last patient history'),
    ('SELECT fhir.vread(''Patient'', (SELECT version_id FROM patient_history ORDER BY updated DESC LIMIT 1));', '6. read previous patient version'),
    ('SELECT fhir.is_exists(''Patient'', (SELECT logical_id FROM patient ORDER BY updated DESC LIMIT 1));\n-- check, if patient still exists', '7. check, if patient still exists'),
    ('SELECT fhir.is_deleted(''Patient'', (SELECT logical_id FROM patient ORDER BY updated DESC LIMIT 1));\n-- check, if patient is deleted', '8. check, if patient is deleted'),
    ('SELECT fhir.delete(''Patient'', (SELECT logical_id FROM patient ORDER BY updated DESC LIMIT 1)); \n-- returns last patient version', '9. delete last patient'),
    ('SELECT fhir.transaction($tr$ { "resourceType":"Bundle", "type":"transaction", "entry": [{"transaction":{"method":"POST", "url":"/Patient"}, "resource":{"resourceType":"Patient", "name":[{"given": ["Mark"]}]} }, { "transaction":{"method":"POST", "url":"/Patient"}, "resource":{"resourceType":"Patient", "name":[{"given": ["Boris"]}]} }, { "transaction":{"method":"POST", "url":"/Patient"}, "resource":{"resourceType":"Patient", "name":[{"given": ["Ted"]}]}}]} $tr$)', '10. create 3 patients in one transaction'),
    ('SELECT fhir.search(''Patient'', ''given=john'')', '11. Search for patient'),
    ('SELECT * from fhir._search(''Patient'', ''given=john&count=10'')', '12. Search as relations')
"""
app.controller 'IndexController', ($scope, $http)->
  codemirrorExtraKeys = window.CodeMirror.normalizeKeyMap
    "Ctrl-Space": "autocomplete"
    "Ctrl-Enter": ()-> $scope.query()

  tables = { "schema":[] }

  $scope.codemirrorOptions =
    lineWrapping : true,
    lineNumbers: true,
    mode: 'sql',
    theme: 'xq-light',
    extraKeys: codemirrorExtraKeys
    viewportMargin: Infinity,
    hint: window.CodeMirror.hint.sql,
    hintOptions:
      tables: tables

  # base_url = 'http://192.168.59.103:8888/'
  baseUrl = BASEURL || "#{window.location.protocol}//#{window.location.host}"
  $scope.sql = 'SELECT 1'

  $scope.trigerState = (st)->
    if $scope.rightPane == st
      delete $scope.rightPane
    else
      $scope.rightPane = st


  query = (sql)->
    $http(
      url: baseUrl,
      method: 'GET',
      params: {sql: sql}
    ).success (data)->
      $scope.queryResultIsEmpty = data.length < 1 ? true : false
      $scope.showResult = true
    .error (data)->
      $scope.showResult = true
      console.log "default error", data

  silentQuery = (sql)->
    $http(
      url: baseUrl,
      method: 'GET',
      params: {sql: sql}
    ).success (data)->
      $scope.queryResultIsEmpty = data.length < 1 ? true : false
    .error (data)->
      console.log "default error", data

  $scope.reloadSidebar = ()->
    silentQuery(SELECT_TBLS)
    .success (data)->
      $scope.tables = data
      tables[tbl.title] = [] for tbl in data

    silentQuery(SELECT_PROCS)
    .success (data)->
      $scope.procs = data
      tables[tbl.title] = [] for tbl in data

    silentQuery("""SELECT * FROM snippets""")
    .success (data)->
      $scope.snippets = data
      $scope.trigerState('snippets')
      $scope.selectSnippet($scope.snippets[0])
    .error ()->
      silentQuery("create table if not exists snippets (sql text, title text)")
        .success ->
          silentQuery("""select count(*) from snippets""").success (data)->
            if data[0].count == 0
              query(CREATE_SNIPS)
              $scope.reloadSidebar()

  $scope.reloadSidebar()

  $scope.enterSql = (ev)->
    if (ev.which == 10 or ev.which == 13)  and ev.ctrlKey
      $scope.query()

  $scope.query = ()->
    query($scope.sql).success (data)->
      $scope.result = data
      $scope.error = '' if $scope.error
    .error (data)->
      $scope.error = true
      $scope.result = []
      d = data.replace(/\n\n/g, "\n").split("<html>")[0]
      $scope.errorMessage = d
      console.log('error', data, arguments)

  $scope.selectSnippet = (item)->
    $scope.sql = item.sql
    $scope.query()

  $scope.selectProc = (item)->
    $scope.sql = "SELECT #{item.title}"

  $scope.selectTable = (item)->
    $scope.sql = "SELECT * FROM \"#{item.title}\" LIMIT 10"
    $scope.query()

  $scope.saveRequestAs = ()->
    query("""insert into snippets (sql, title) values
              ($$ #{$scope.sql} $$, E'#{$scope.sql_title}')""")
    .success (data)->
      $scope.sql_title = ''
      $scope.reloadSidebar()

window.app = app
