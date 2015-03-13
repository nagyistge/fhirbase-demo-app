require('../../bower_components/angular/angular.js')
require('../../bower_components/angular-route/angular-route.js')
require('../../bower_components/angular-sanitize/angular-sanitize.js')
require('../../bower_components/angular-animate/angular-animate.js')
require('../../bower_components/angular-cookies/angular-cookies.js')

require('file?name=index.html!../index.html')
require('file?name=fhir.jsofile?name=fhir.json!../fhir.json')
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

app.config ($httpProvider) ->
  console.log('here')

activate = (name)->
  sitemap.main.forEach (x)->
    if x.name == name
      x.active = true
    else
      delete x.active

app.run ($rootScope, $window, $location, $http)->

app.controller 'IndexController', ($scope, $http)->
  base_url = 'http://192.168.59.103:8888/'
  query = (sql)->
    $http(
      url: base_url,
      method: 'GET',
      params: {sql: sql}
    )

  query("""create table if not exists snippets (sql text, title text)""")
    .success ->
      query("""select count(*) from snippets""").success (data)->
        if data[0].count == 0
          query("""insert into snippets (sql, title) values
                      ('select * from snippets', 'show snippets'),
                      ('select * from alert', 'show alerts'),
                      ('select * from appointment', 'show appointments')""")

  $scope.reloadSidebar = ()->
    query("""SELECT * FROM pg_catalog.pg_tables where schemaname = 'public' 
               order by tablename;""")
    .success (data)->
      $scope.tables = data

    query("""SELECT * FROM snippets""")
    .success (data)->
      $scope.snippets = data
  $scope.reloadSidebar()

  $scope.sql = 'SELECT 1'
  $scope.enterSql = (ev)->
    if (ev.which == 10 or ev.which == 13)  and ev.ctrlKey
      $scope.query()

  $scope.query = ()->
    query($scope.sql).success (data)->
      $scope.result = data
      $scope.error = '' if $scope.error
    .error (data)->
      $scope.error = true
      $scope.errorMessage = data
      console.log('error', data, arguments)

  $scope.selectSnippet = (item)->
    $scope.sql = item.sql
    $scope.query()


  # $scope.query()

window.app = app
