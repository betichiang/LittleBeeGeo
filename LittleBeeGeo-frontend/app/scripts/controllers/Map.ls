'use strict'

{map, fold, fold1, mean, join} = require 'prelude-ls'

LEGENDS = <[ ]>

CONFIG = window.LittleBeeGeo.CONFIG

# LEGEND_STRING =

# LEGEND_COLOR =

COLOR_REPORT = \#0F8
ICON_REPORT = \report.png
COLOR_REPORT_PATH = \#0FF
COLOR_CURRENT_POSITION = \#000
ICON_CURRENT_POSITION = \img/bee.png
ICON_BEEZ_POSITION = \img/littlebeeflower3.png

_REPORT_TEXT_MAP = 
  yes: \回報
  no: "瀏覽 (按我回報資訊)"

SubmitCtrl = <[ $scope $modalInstance items TWCounties TWTown adData ]> ++ ($scope, $modalInstance, items, TWCounties, TWTown, adData) ->
  {BACKEND_HOST} = CONFIG
  $scope <<< {BACKEND_HOST}

  $scope.formatAd = (data) ->
    console.log 'formatAd: data:', data
    '<table><tr><td class="poster-img"><img class="flag" src="http://' + BACKEND_HOST + '/get/thumbnail/' + data.element[0].id + '"/></td><td>' + data.text + '</td><tr>'

  $scope.Ads = [{"name": ""}]
  $scope.$watch (-> adData.getDataTimestamp!), ->
    the_data = adData.getData!

    console.log 'adData: the_data:', the_data

    data = [val for key, val of the_data]

    $scope.Ads = [{"name": "", "the_type": ""}] ++ data

  $scope.onSubmitOk = ->
    console.log 'to submit: items:', items
    $modalInstance.close $scope.submit

  $scope.onSubmitCancel = ->
    $modalInstance.dismiss('cancel')

  $scope.submit = {deliver_date: new Date!, ad_versions: []}

  $scope.dateOptions =
    \year-format: \'yyyy'
    \starting-day: 0

  $scope.date_opened = true

  $scope.dateOpen = ($event) ->
    $event.preventDefault!
    $event.stopPropagation!

    $scope.date_opened = true

  $scope.format = 'yyyy-MM-dd'

  CountyOpts =
    placeholder: "我在哪個城市? "

  county_list = [{"name": ""}] ++ TWCounties.getCounties!

  $scope.$watch (-> $scope.submit.county), ->
    tw_town = TWTown.getTown!
    town_list = [{"name": ""}] ++ tw_town[it]
    $scope <<< {TWTown: town_list}

  TownOpts =
    placeholder: "我在哪個區域? "

  AdOpts =
    placeholder: "我這次發了哪些文宣? "
    multiple: true

  $scope <<< {TWCounties: county_list, CountyOpts, TWTown: [{"name": ""}], TownOpts, AdOpts}


angular.module 'LittleBeeGeoFrontend'
  .controller 'MapCtrl',  <[ $scope geoAccelGyro jsonData reportList $modal ]> ++ ($scope, geoAccelGyro, jsonData, reportList, $modal) ->
    geo = geoAccelGyro.getGeo!

    states = {isReport: "no"}
    #states <<< {['is_show_' + legend_type, true] for legend_type in LEGENDS}
    #the_legend_color = {[key, val] for key, val of LEGEND_COLOR}
    $scope <<< {states}
    #$scope <<< {states, LEGENDS, LEGEND_STRING, LEGEND_COLOR: the_legend_color, LEGEND_MAP}

    $scope.report_text = _REPORT_TEXT_MAP

    $scope.mapOptions = 
      center: new google.maps.LatLng geo.lat, geo.lon
      zoom: 16
      draggableCursor: 'pointer' 
      draggingCursor: 'pointer' 
      mapTypeId: google.maps.MapTypeId.ROADMAP

    $scope.zoom = 16

    is_first_map_center = true

    current_position_marker = do
      marker: void

    $scope.$on 'geoAccelGyro:event', (e, data) ->

      if data.event != 'devicegeo'
          return

      console.log 'Map: geoAccelGyro:event: data:', data

      if is_first_map_center
        console.log 'to set is_first_map_center as false'
        is_first_map_center := false

        $scope.myMap.setCenter (new google.maps.LatLng data.lat, data.lon)

      _update_current_position_marker data, current_position_marker

    $scope.$watch (-> jsonData.getDataTimestamp!), ->
      the_data = jsonData.getData!

      console.log 'Map: the_data:', the_data

      data = [val for key, val of the_data]
      markers = _parse_markers data

      console.log 'markers:', markers

      $scope.markers = markers

    $scope.onMapIdle = -> 
      if states.isReport is "yes"
        $scope.mapOptions.draggableCursor = "crosshair"
        $scope.mapOptions.draggingCursor = "crosshair"
      else
        $scope.mapOptions.draggableCursor = "pointer"
        $scope.mapOptions.draggingCursor = "pointer"

    $scope.reportMarkers = []

    $scope.onMapClick = (event, params) ->
      console.log 'onMapClick: event:', event, 'params:', params

      if states.isReport is "no"
        return

      is_remove_same_point = if event.is_remove_same_point == false then false else true

      reportList.setMarker params[0], $scope.zoom, is_remove_same_point
      report_list = reportList.getList!

      _remove_markers_from_googlemap $scope.reportMarkers

      markers = _add_markers_to_googlemap report_list, COLOR_REPORT
      path_markers = _add_marker_paths_to_googlemap_from_markers report_list, COLOR_REPORT_PATH
      $scope.reportMarkers = markers ++ path_markers

    $scope.onZoomIn = ->
      console.log 'onZoomIn: zoom:', $scope.zoom
      if $scope.zoom == 17
        return

      $scope.zoom += 1

      $scope.myMap.setZoom $scope.zoom

    $scope.onZoomOut = ->
      console.log 'onZoomIn: zoom:', $scope.zoom
      if $scope.zoom == 3
        return

      $scope.zoom -= 1

      $scope.myMap.setZoom $scope.zoom

    $scope.onMapZoomChanged = (zoom) ->
      console.log 'onMapZoomChanged: zoom:', zoom
      $scope.zoom = zoom

    $scope.onClearReportList = ->
      console.log 'onClearReportList: start'
      reportList.clearList!
      _remove_markers_from_googlemap $scope.reportMarkers
      $scope.reportMarkers = []

    $scope.onAddCurrentLocation = ->
      if current_position_marker.marker is void then return

      latLng = current_position_marker.marker.getPosition!

      $scope.onMapClick {'event_type': 'onAddCurrentLocation', 'is_remove_same_point': false}, [{latLng}]

    $scope.onSubmit = ->
      modalInstance = $modal.open do
        templateUrl: '/views/submit.html',
        controller: SubmitCtrl,
        resolve: 
          items: ->
            {}

      submit-form = (items) ->
        console.log 'MapCtrl: to submit-form: items:', items

        report_list = reportList.getList!

        console.log 'report_list:', report_list

        geo_info = []
        if report_list.length == 1
          point_info = [report_list[0].latLng.lng!, report_list[0].latLng.lat!]
          geo_info = [{type: \Point, coordinates: point_info}]
        else
          line_info = [[each_data.latLng.lng!, each_data.latLng.lat!] for each_data in report_list]
          geo_info = [{type: \LineString, coordinates: line_info}]
        items.geo = geo_info
        items.deliver_time = parseInt items.deliver_date.getTime! / 1000
        items.count = parseInt items.count

        jsonData.submitData [items]

        reportList.clearList!
        _remove_markers_from_googlemap $scope.reportMarkers
        $scope.reportMarkers = []

      submit-dismissed = ->
        console.log 'dismissed: %s', new Date!.toDateString!

      modalInstance.result.then submit-form, submit-dismissed

    _MercatorProjection = ->
      pixel_origin = new google.maps.Point (TILE_SIZE / 2), (TILE_SIZE / 2)
      pixels_per_lon_deg = TILE_SIZE / 360;
      piexls_per_lon_radius = TILE_SIZE / (2 * Math.PI);

      return {pixel_origin, piexls_per_lon_deg, piexls_per_lon_radius}

    _lat_lon_to_pixel = (latlon, map) ->
      proj = $scope.myMap.getProjection!

      p = new google.maps.Point(0, 0);

      p.x = origin.x + latLng.lng()
      p = proj.fromLatLngToContainerPixel latlon

    _update_current_position_marker = (data, current_position_marker) ->
      position = new google.maps.LatLng data.lat, data.lon
      console.log 'position:', position
      if current_position_marker.marker is void
        bee =
          url: ICON_CURRENT_POSITION
          size: new google.maps.Size 56, 56
          scaledSize: new google.maps.Size  30, 30
          origin: new google.maps.Point 0, 0
          anchor: new google.maps.Point 12, 12

        marker_opt30=
          map: $scope.myMap
          position: position
          fillColor: COLOR_CURRENT_POSITION
          strokeColor: COLOR_CURRENT_POSITION
          icon: bee
          zIndex: 9999

        current_position_marker.marker = new google.maps.Marker marker_opt30
      else
        current_position_marker.marker.setPosition position

    _set_markers_to_googlemap = (markers) ->
      markers |> map (marker) -> marker.setMap $scope.myMap

    _remove_markers_from_googlemap = (markers) ->
      console.log '_remove_markers_from_googlemap: markers:', markers
      markers |> map (marker) -> marker.setMap void

    _add_markers_to_googlemap = (markers, color) ->
      markers |> map (marker) -> _add_marker_to_googlemap marker, color

    _add_marker_to_googlemap = (data, color) ->
      console.log '_add_marker_to_googlemap: data:', data, 'color:', color
      positions = [val for key, val of data.latLng]

      marker_opts =
        map: $scope.myMap
        position: data.latLng
        fillColor: color
        strokeColor: color

      marker = new google.maps.Marker marker_opts
      marker

    _add_marker_paths_to_googlemap_from_markers = (markers, color) ->
      console.log '_add_marker_paths_to_googlemap_from_markers:', markers

      if markers.length < 2 then return []

      the_markers = markers[0 to -2]
      next_markers = markers[1 to -1]

      idx_list = [0 to the_markers.length - 1]
      marker_list = [{the_marker: the_markers[idx], next_marker: next_markers[idx]} for idx in idx_list]
      marker_list |> map (x) -> _add_marker_path_to_googlemap x, color

    _add_marker_path_to_googlemap = (data, color) ->
      console.log 'data:', data
      current_coord = data.the_marker.latLng
      next_coord = data.next_marker.latLng
      polyline_opts =
        map: $scope.myMap
        path: [current_coord, next_coord]
        fillColor: color
        strokeColor: color

      new google.maps.Polyline polyline_opts

    _parse_markers = (the_data_values) ->
      console.log '_parse_markers: the_data_values:', the_data_values
      results = [_parse_marker each_value for each_value in the_data_values]
      results = [val for val in results when val is not void]
      results |> fold1 (++)

    _parse_marker = (value) ->
      #console.log '_parse_marker: value', value
      geo = value.geo
      if geo is void
        return void

      color = _parse_marker_color(value)

      console.log '_parse_marker: geo:', geo

      markers = [_parse_each_marker each_geo, color, value for each_geo in geo]

      console.log 'after _parse_each_marker: markers:', markers

      [_add_map_listener each_marker for each_marker in markers]

      markers

    _parse_marker_color = (value) ->
      \#840

    #_parse_each_marker
    _parse_each_marker = (geo, color, value) ->
      the_type = geo.type
      the_coordinates = geo.coordinates

      console.log '_parse_each_marker: geo:', geo, 'the_type:', the_type, 'the_coordinates', the_coordinates
      switch the_type
      | 'Polygon'    => _parse_polygon the_coordinates, color, value
      | 'LineString' => _parse_line_string the_coordinates, color, value
      | 'Point'      => _parse_point the_coordinates, color, value

    _parse_polygon = (coordinates, color, value) ->
      polygon_opts = 
        map: $scope.myMap,
        paths: [_parse_path coord for coord in coordinates]
        fillColor: color
        strokeColor: color

      polygon = new google.maps.Polygon polygon_opts
      polygon._value = value
      polygon

    _parse_line_string = (coordinates, color, value) ->
      polyline_opts = 
        map: $scope.myMap
        path: _parse_path coordinates
        fillColor: color
        strokeColor: color

      polyline = new google.maps.Polyline polyline_opts
      polyline._value = value
      console.log '_parse_line_string: polyline_opts:', polyline_opts, 'polyline:', polyline
      polyline

    _parse_point = (coordinates, color, value) ->
      console.log '_parse_point: coordinates:', coordinates, 'color:', color, 'value:', value

      beez =
        url: ICON_BEEZ_POSITION
        size: new google.maps.Size 50, 70
        scaledSize: new google.maps.Size 25, 35
        origin: new google.maps.Point 0, 0
        anchor: new google.maps.Point 12, 12

      marker_opts = 
        map: $scope.myMap
        position: new google.maps.LatLng coordinates[1], coordinates[0]
        fillColor: color
        strokeColor: color
        icon: beez

      marker = new google.maps.Marker marker_opts
      marker._value = value
      marker

    _parse_path = (coordinates) ->
      console.log '_parse_path: coordinates', coordinates
      [new google.maps.LatLng coord[1], coord[0] for coord in coordinates]

    #_add_map_listener
    info_window = new google.maps.InfoWindow do
      content: 'Hello World'

    _add_map_listener = (marker) ->
      console.log '_add_map_listener: start: marker:', marker

      google.maps.event.addListener marker, 'click', (event) ->

        console.log 'map_listener: marker:', marker

        if event is not void
          info_window.setPosition event.latLng
          info_window.open $scope.myMap
          info_window.setContent _parse_content marker._value

    _parse_content = (value) ->
      the_user_name = if value.user_name then value.user_name else ''
      the_address = if value.address then value.address else ''

      deliver_datetime = new Date(value.deliver_time * 1000);
      the_ad_versions = join ', ', value.ad_versions

      result = '<div>' + \
        '<p>' + _parse_content_join_str([value.county, value.town]) + '</p>' + \
        '<p>' + the_address + '</p>' + \
        '<p>' + the_user_name + '</p>' + \
        '<p>' + deliver_datetime.toLocaleString! + '</p>' + \
        '<p>' + the_ad_versions + '</p>'

      #if value.deliver_status:
      #  result += '<p>' + value.deliver_status + '</p>'

      result += '</div>'

      result

    _parse_content_join_str = (the_list) ->
      the_list = [column for column in the_list when column]
      return join ' / ' the_list
