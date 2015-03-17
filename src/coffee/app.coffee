window.CodeMirror = require('../../bower_components/codemirror/lib/codemirror.js')
require('../../bower_components/angular/angular.js')
require('../../bower_components/angular-route/angular-route.js')
require('../../bower_components/angular-sanitize/angular-sanitize.js')
require('../../bower_components/angular-animate/angular-animate.js')
require('../../bower_components/angular-cookies/angular-cookies.js')
require('../../bower_components/angular-ui-codemirror/ui-codemirror.js')
require('../../bower_components/codemirror/mode/sql/sql.js')

require('../../bower_components/codemirror/lib/codemirror.css')
require('../../bower_components/codemirror/theme/xq-light.css')

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

app.controller 'IndexController', ($scope, $http)->
  codemirrorExtraKeys = window.CodeMirror.normalizeKeyMap({
    "Ctrl-Enter": ()->
      $scope.query()
    })

  $scope.codemirrorOptions = {
    lineWrapping : true,
    lineNumbers: true,
    mode: 'sql',
    theme: 'xq-light',
    viewportMargin: Infinity,
    extraKeys: codemirrorExtraKeys
  }

  # base_url = 'http://192.168.59.103:8888/'
  baseUrl = BASEURL || "#{window.location.protocol}//#{window.location.host}"
  $scope.sql = 'SELECT 1'

  query = (sql)->
    $http(
      url: baseUrl,
      method: 'GET',
      params: {sql: sql}
    ).success (data)->
      $scope.queryResultIsEmpty = data.length < 1 ? true : false
      $scope.showResult = true
    .error (data)->
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
    silentQuery("""SELECT * FROM pg_catalog.pg_tables where schemaname = 'public'
               order by tablename;""")
    .success (data)->
      $scope.tables = data

    silentQuery("""SELECT * FROM snippets""")
    .success (data)->
      $scope.snippets = data
    .error ()->
      silentQuery("create table if not exists snippets (sql text, title text)")
        .success ->
          silentQuery("""select count(*) from snippets""").success (data)->
            if data[0].count == 0
              query("""insert into snippets (sql, title) values
                          ('select * from snippets', 'show snippets'),
                          ('select * from alert', 'show alerts'),
                          ('select * from appointment', 'show appointments')
              """)
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
      d = data.replace(/\n\n/g, "\n").split("<html>")[0]
      $scope.errorMessage = d
      console.log('error', data, arguments)

  $scope.selectSnippet = (item)->
    $scope.sql = item.sql
    $scope.showRightBar = false
    $scope.query()

  $scope.saveRequestAs = ()->
    query("""insert into snippets (sql, title) values
              ($$ #{$scope.sql} $$, E'#{$scope.sql_title}')""")
    .success (data)->
      $scope.sql_title = ''
      $scope.reloadSidebar()

window.app = app
