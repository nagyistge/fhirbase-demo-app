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
  $scope.sql = 'SELECT 1'
  $scope.enterSql = (ev)->
    console.log(ev)
    if ev.which == 10 and ev.ctrlKey
      $scope.query()

  $scope.query = ()->
    $http(
      url: 'http://172.17.0.12:8888/'
      method: 'GET'
      params: {sql: $scope.sql}
    ).success (data)->
      console.log(data)
      $scope.result = data
    .error (data)->
      $scope.error = true
      $scope.errorMessage = data
      console.log('error', data, arguments)
  $scope.query()

window.app = app
