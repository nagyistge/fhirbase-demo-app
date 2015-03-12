window.app.controller 'IndexController', ($scope, $interval, $fhir)->
  $scope.labs = [
    {id: '14f6cb8a-d281-47e4-87bf-e8f0569f976b', label: 'Laboratory 1'},
    {id: 'bc0387a8-9a7f-48b3-a812-dc8f9742d2d7', label: 'Laboratory 2'}
  ]
  $scope.laboratory = $scope.labs[0]
  $scope.orders = []
  $scope.loadingOrders = false

  $scope.setupUpdateInterval = ->
    if $scope.updateInterval
      $interval.cancel($scope.updateInterval)
    $scope.updateInterval = $interval(fetchOrders, 5000)

  $scope.$watch 'laboratory', ->
    $scope.orders = []
    $scope.setupUpdateInterval()
    fetchOrders()

  fetchOrders = ()->
    if !$scope.laboratory
      return
    $scope.loadingOrders = true
    # TODO: set real Organization selector
    $fhir.search(type: 'Order', query: {target: "Organization/f001"})
    # $fhir.search(type: 'Order', query: {target: $scope.laboratory.id})
      .success (data)->
        console.log data
        receivedId = data.entry[0]?.resource?.target?.reference.split("Organization/").slice(-1)[0]
        console.log receivedId
        if true
        # TODO: set real laboratory.id check
        # if receivedId == $scope.laboratory.id
          newOrders = data.entry.map (e)-> 
            angular.extend e.resource, {_id: e.resource.id, date: new Date(e.resource.date)}
          scopeOrderIds = $scope.orders.map((o)-> o._id)
          if $scope.orders.length > 0
            for order in newOrders
              isNew = scopeOrderIds.indexOf(order._id) == -1
              if isNew
                $scope.orders.push(angular.extend order, {_new: true})
          else
            $scope.orders = newOrders.map (order)->
              order._new = false
              order
          $scope.loadingOrders = false
        else
          return

  $scope.setupUpdateInterval()
  fetchOrders()
