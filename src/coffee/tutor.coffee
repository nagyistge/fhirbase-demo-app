window.CodeMirror = require('../../bower_components/codemirror/lib/codemirror.js')
require('../../bower_components/angular/angular.js')
require('../../bower_components/angular-route/angular-route.js')
require('../../bower_components/angular-sanitize/angular-sanitize.js')
require('../../bower_components/angular-animate/angular-animate.js')
require('../../bower_components/angular-cookies/angular-cookies.js')
require('../../bower_components/angular-ui-codemirror/ui-codemirror.js')
require('../../bower_components/codemirror/mode/sql/sql.js')

require('../../bower_components/codemirror/lib/codemirror.css')
require('../../bower_components/codemirror/theme/tomorrow-night-eighties.css')
require('../../bower_components/codemirror/theme/xq-light.css')
require('../../bower_components/codemirror/addon/hint/show-hint.css')
require('../../bower_components/codemirror/addon/hint/show-hint.js')
require('../../bower_components/codemirror/addon/hint/sql-hint.js')

require('file?name=tutorial.html!../tutorial.html')
require('file?name=fhir.json!../fhir.json')
require('../less/app.less')

app = require('./module')

require('./views')

app.config ['$routeProvider', ($routeProvider) ->
  $routeProvider
    .when '/',
      template: require('../views/tutor.md')
    .otherwise
      templateUrl: '/views/404.html'
]

_nextId = 0
nextId = ()->
  _nextId++

app.directive 'pre', ()->
  restrict: 'E'
  replace: true
  template: (el)->
    sql = el.find('code').text()
    modelId = "sql#{nextId()}"
    result = """<div>
      <textarea ui-codemirror="codemirrorOptions"
      class="outline" ng-model="#{modelId}"
      ng-init='#{modelId}=#{JSON.stringify(sql).replace(/'/g, "&#39;")}'>
      </textarea>
      <button class="btn btn-success btn-run" ng-click="query(#{modelId})">Run</button>
      </div>
    """
    result

app.run ($rootScope, $window, $location, $http)->
  baseUrl = BASEURL || "#{window.location.protocol}//#{window.location.host}"
  codemirrorExtraKeys = window.CodeMirror.normalizeKeyMap
    "Ctrl-Space": "autocomplete"

  $rootScope.steps =
    step1: 'SELECT 1'

  tables = []
  $rootScope.codemirrorOptions =
    lineWrapping : true,
    lineNumbers: false,
    mode: 'sql',
    theme: 'tomorrow-night-eighties',
    extraKeys: codemirrorExtraKeys
    viewportMargin: Infinity,
    hint: window.CodeMirror.hint.sql,
    hintOptions:
      tables: tables
  query = (sql)->
    $rootScope.queryStart = new Date().getTime()
    $http(
      url: baseUrl,
      method: 'GET',
      params: {sql: sql}
    ).success (data)->
      $rootScope.queryTiming = new Date().getTime() - $rootScope.queryStart
      $rootScope.queryResultIsEmpty = data.length < 1 ? true : false
      $rootScope.showResult = true
      $rootScope.result = data
      $rootScope.error = '' if $rootScope.error
    .error (data)->
      $rootScope.error = true
      $rootScope.showResult = true
      $rootScope.result = []
      d = data.replace(/\n\n/g, "\n").split("<html>")[0]
      $rootScope.errorMessage = d
      console.log('error', data, arguments)
  $rootScope.query = query
