angular.module('sensorProfile', [])
.controller('MainCtrl', [
  '$scope','$http',
  function($scope,$http){
    $scope.hide = true;
    $scope.show = true;
    $scope.timings = [];
    $scope.allTemps = [];
    $scope.violations = [];
    $scope.currentTemp = 0;
    $scope.threshold = 0;
    $scope.location = 0;
    $scope.name = 0;
    $scope.numToNotify = "";
    $scope.eci = "JhVNNtbaPJZkFVQPp9hF51";
    $scope.host = "http://localhost:8080";
    
    // Function used to grab the current temperature of the Wovyn sensor.
    var aURL = $scope.host+'/sky/cloud/'+$scope.eci+'/temperature_store_v2/current_temperature';
    $scope.getCurrentTemp = function() {
      return $http.get(aURL).success(function(data){
        $scope.currentTemp = angular.copy(data);
      });
    };

    // Function used to grab the all temperatures that have been recorded from a Wovyn sensor heartbeat.
    var tURL = $scope.host+'/sky/cloud/'+$scope.eci+'/temperature_store_v2/temperatures';
    $scope.getAllTemps = function() {
      return $http.get(tURL).success(function(data){
        angular.copy(data, $scope.allTemps);
      });
    };

    // Function used to grab the threshold violations that have been recorded by the Wovyn Pico.
    var vURL = $scope.host+'/sky/cloud/'+$scope.eci+'/temperature_store_v2/threshold_violations';
    $scope.getAllViolations = function() {
      return $http.get(vURL).success(function(data){
        angular.copy(data, $scope.violations);
      });
    };

    var lURL = $scope.host+'/sky/cloud/'+$scope.eci+'/sensor_profile/sensor_location';
    $scope.getLocation = function() {
      return $http.get(lURL).success(function(data){
        $scope.location = angular.copy(data);
      });
    };

    var thURL = $scope.host+'/sky/cloud/'+$scope.eci+'/sensor_profile/sensor_threshold';
    $scope.getThreshold = function() {
      return $http.get(thURL).success(function(data){
        $scope.threshold = angular.copy(data);
      });
    };

    var nURL = $scope.host+'/sky/cloud/'+$scope.eci+'/sensor_profile/sensor_name';
    $scope.getName = function() {
      return $http.get(nURL).success(function(data){
        $scope.name = angular.copy(data);
      });
    };

    var pURL = $scope.host+'/sky/cloud/'+$scope.eci+'/sensor_profile/notify_who';
    $scope.getPhoneNumber = function() {
      return $http.get(pURL).success(function(data){
        $scope.numToNotify = angular.copy(data);
      });
    };

    $scope.displayProfile = function() {
      $scope.getLocation();
      $scope.getThreshold();
      $scope.getName();
      $scope.getPhoneNumber();
      $scope.hide = false;
      $scope.show = false;
    };

    $scope.hideProfile = function() {
      $scope.hide = true;
      $scope.show = true;
    };

    var upURL = $scope.host+'/sky/event/'+$scope.eci+'/eid/sensor/profile_updated';
    $scope.updateProfile = function() {
      var finalURL = upURL + "?threshold="+ $scope.threshold +"&location="+ $scope.location +"&name="+ $scope.name +"&send_to="+ $scope.numToNotify;
      return $http.post(finalURL).success(function(data){
        $scope.displayProfile();
      });
    };


    $scope.getCurrentTemp();
    $scope.getAllTemps();
    $scope.getAllViolations();
  }
]);