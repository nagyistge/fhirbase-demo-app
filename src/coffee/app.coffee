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
  if window.location.protocol == 'https:'
    window.location.protocol = 'http:'


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
    ('SELECT fhir_create_storage(''{"resourceType": "Patient"}''::json);\n-- Create patients storage', '1. Create patients storage'),
    ('SELECT fhir_create_resource(''{"resource": {"resourceType": "Patient", "name": [{"given": ["Smith"]}]}}'');\n-- Create patient', '2. Create patient'),
    ('SELECT fhir_create_resource(''{"allowId": true, "resource": {"resourceType": "Patient", "id": "smith"}}'');\n-- Create patient with id', '3. Create patient with specific id'),
    ('SELECT resource_type, id, version_id, resource from patient ORDER BY updated_at DESC limit 10;\n-- show last 10 patients', '4. Show patients table'),
    ('SELECT fhir_read_resource(''{"resourceType": "Patient", "id": "smith"}'');\n-- Show patient by id using fhirbase API', '5. Show patient by id'),
    ('SELECT fhir_update_resource(''{"resource": {"resourceType": "Patient", "id": "smith", "name": [{"given": ["John"], "family": ["Smith"]}]}}'');\n-- Update patient by id', '6. Update patient by id'),
    ('SELECT fhir_resource_history(''{"resourceType": "Patient", "id": "smith"}'');\n-- Show patient''s history', '7. Show patient''s history'),
    ('SELECT fhir_search(''{"resourceType": "Patient", "queryString": "name=smith"}'');\n-- Patient search', '8. Patient search'),
    ('SELECT fhir_search_sql(''{"resourceType": "Patient", "queryString": "name=smith"}'');\n-- See generated SQL', '9. See generated SQL'),
    ('SELECT fhir_delete_resource(''{"resourceType": "Patient", "id": "smith"}'');\n --mark resource as deleted (i.e. keep history) ', '10. Delete resource'),
    ('SELECT fhir_resource_history(''{"resourceType": "Patient", "id": "smith"}'');', '11. One more history'),
    ('SELECT fhir_terminate_resource(''{"resourceType": "Patient", "id": "smith"}'');\n-- completely delete resource and its history', '12. Completely delete patient'),
    ('SELECT fhir_resource_history(''{"resourceType": "Patient", "id": "smith"}'');', '13. And one more history time'),
    ('with t as (SELECT  json_array_elements(fhir_search(
            ''{"resourceType": "Patient", 
              "queryString": "birthdate=lt1966"}''
      )::json->''entry'') as resource)
      select 
        resource->''resource''->''id'' as id, 
        resource->''resource''->''name'' as name,
        resource->''resource''->''birthDate'' as birthdate
      from t;', '14. Select patients older than 50 years'),

    ('
  with 
    e as (
      SELECT 
        resource#>>''{period,start}'' as visit_date,
        resource#>>''{patient,reference}'' as patient
      FROM encounter
    ),
    p as (
      SELECT 
        resource->>''id'' as id,
        resource->''name'' as name,
        age(DATE(resource->>''birthDate''))::text as age,
        DATE(resource->>''birthDate'') as birthdate
      FROM patient
    )
  SELECT 
    p.id as patient, 
    p.name as name, 
    e.visit_date as visit_date,
    p.age as age
  FROM e
  JOIN p 
    on concat(''Patient/'', p.id) = e.patient
  WHERE 
    DATE(e.visit_date) >= (NOW()-(interval ''1 week''))
    AND p.birthdate <= DATE(''1966-01-01'') ;\n --Select patient older than 50 year and had encounter on last week
    ', '15. Select patient older than 50 year and had encounter on last week'),
    ('
  with 
    e as (
      SELECT 
        resource#>>''{period,start}'' as visit_date,
        resource#>>''{patient,reference}'' as patient
      FROM encounter
    ),
    p as (
      SELECT 
        resource->>''id'' as id,
        resource->''name'' as name,
        age(DATE(resource->>''birthDate''))::text as age,
        DATE(resource->>''birthDate'') as birthdate
      FROM patient
    )
  SELECT to_date(e.visit_date, ''YYYY-MM-DD'') as date, count(*) as visits, array_agg(p.id) as patient_ids
  FROM e
  JOIN p 
    on concat(''Patient/'', p.id) = e.patient
  GROUP BY date
  ORDER BY visits desc;', '16. Show count of visits by date'),
  ('SELECT fhirbase_version();\n-- Show Fhirbase version', '17. Show Fhirbase version')

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
