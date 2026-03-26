Hecks.domain "HecksParcels" do
  aggregate "Project" do
    attribute :name, String
    attribute :boundary, list_of("Point")
    attribute :boundary_stroke_color, String
    attribute :boundary_line_width, Float

    validation :name, presence: true

    value_object "Point" do
      attribute :x, Float
      attribute :y, Float
    end

    command "CreateProject" do
      attribute :name, String
    end

    command "SetBoundary" do
      attribute :project_id, reference_to("Project")
      attribute :boundary, list_of("Point")
    end

    command "MoveBoundaryVertex" do
      attribute :project_id, reference_to("Project")
      attribute :vertex_index, Integer
      attribute :x, Float
      attribute :y, Float
    end

    command "UpdateBoundaryStyle" do
      attribute :project_id, reference_to("Project")
      attribute :stroke_color, String
      attribute :line_width, Float
    end

    query "ByName" do |name|
      where(name: name)
    end
  end

  aggregate "Road" do
    attribute :name, String
    attribute :road_type, String
    attribute :row_width, Float
    attribute :show_setbacks, :boolean
    attribute :setback_distance, Float
    attribute :locked, :boolean
    attribute :custom_type_label, String
    attribute :project_id, reference_to("Project")
    attribute :points, list_of("RoadPoint")
    attribute :radii, Array

    validation :name, presence: true

    value_object "RoadPoint" do
      attribute :x, Float
      attribute :y, Float
      attribute :attached_to, String
    end

    specification "NotLocked" do |road|
      !road.locked
    end

    command "CreateRoad" do
      attribute :project_id, reference_to("Project")
      attribute :name, String
      attribute :points, list_of("RoadPoint")
      sets road_type: "collector", row_width: 80.0,
           show_setbacks: false, setback_distance: 0.0,
           locked: false
    end

    command "DeleteRoad" do
      attribute :road_id, reference_to("Road")
    end

    command "MoveRoadVertex" do
      attribute :road_id, reference_to("Road")
      attribute :vertex_index, Integer
      attribute :x, Float
      attribute :y, Float
      attribute :snap_radius, Float
    end

    command "MoveRoadSegment" do
      attribute :road_id, reference_to("Road")
      attribute :segment_index, Integer
      attribute :dx, Float
      attribute :dy, Float
    end

    command "ChangeRoadRadius" do
      attribute :road_id, reference_to("Road")
      attribute :vertex_index, Integer
      attribute :radius, Float
    end

    command "JoinRoads" do
      attribute :road_id, reference_to("Road")
      attribute :other_road_id, reference_to("Road")
    end

    command "UpdateRoadProps" do
      attribute :road_id, reference_to("Road")
      attribute :name, String
      attribute :road_type, String
      attribute :row_width, Float
      attribute :show_setbacks, :boolean
      attribute :setback_distance, Float
      attribute :custom_type_label, String
    end

    command "LockRoad" do
      attribute :road_id, reference_to("Road")
    end

    command "UnlockRoad" do
      attribute :road_id, reference_to("Road")
    end
  end

  aggregate "ParcelLine" do
    attribute :project_id, reference_to("Project")
    attribute :points, list_of("LinePoint")

    value_object "LinePoint" do
      attribute :x, Float
      attribute :y, Float
    end

    command "CreateParcelLine" do
      attribute :project_id, reference_to("Project")
      attribute :points, list_of("LinePoint")
    end

    command "DeleteParcelLine" do
      attribute :parcel_line_id, reference_to("ParcelLine")
    end

    command "MoveParcelLineVertex" do
      attribute :parcel_line_id, reference_to("ParcelLine")
      attribute :vertex_index, Integer
      attribute :x, Float
      attribute :y, Float
    end

    command "AddParcelLineNode" do
      attribute :parcel_line_id, reference_to("ParcelLine")
      attribute :after_index, Integer
      attribute :x, Float
      attribute :y, Float
    end

    command "DeleteParcelLineNode" do
      attribute :parcel_line_id, reference_to("ParcelLine")
      attribute :node_index, Integer
    end
  end

  aggregate "Parcel" do
    attribute :project_id, reference_to("Project")
    attribute :name, String
    attribute :points, list_of("ParcelPoint")
    attribute :area, Float
    attribute :color, String
    attribute :density, Float
    attribute :is_residential, :boolean
    attribute :lot_size, Float
    attribute :net_lot_size, Float
    attribute :lot_count, Integer
    attribute :avg_lot_size, String
    attribute :use_type, String
    attribute :custom_use, String
    attribute :custom_color, String
    attribute :local_road_width, Float
    attribute :grid_rotation, Float
    attribute :grid_center_x, Float
    attribute :grid_center_y, Float
    attribute :locked, :boolean

    value_object "ParcelPoint" do
      attribute :x, Float
      attribute :y, Float
    end

    specification "Residential" do |parcel|
      parcel.is_residential
    end

    specification "NotLocked" do |parcel|
      !parcel.locked
    end

    command "GenerateParcel" do
      attribute :project_id, reference_to("Project")
      attribute :name, String
      attribute :points, list_of("ParcelPoint")
      attribute :area, Float
      sets density: 4.0, is_residential: true,
           local_road_width: 50.0, grid_rotation: 0.0,
           locked: false
    end

    command "UpdateParcelProps" do
      attribute :parcel_id, reference_to("Parcel")
      attribute :name, String
      attribute :density, Float
      attribute :is_residential, :boolean
      attribute :avg_lot_size, String
      attribute :use_type, String
      attribute :custom_use, String
      attribute :custom_color, String
      attribute :local_road_width, Float
      attribute :grid_rotation, Float
    end

    command "LockParcel" do
      attribute :parcel_id, reference_to("Parcel")
    end

    command "UnlockParcel" do
      attribute :parcel_id, reference_to("Parcel")
    end

    query "Residential" do
      where(is_residential: true)
    end

    query "ByUseType" do |use_type|
      where(use_type: use_type)
    end
  end

  aggregate "NetArea" do
    attribute :project_id, reference_to("Project")
    attribute :name, String
    attribute :points, list_of("AreaPoint")
    attribute :area, Float
    attribute :locked, :boolean

    value_object "AreaPoint" do
      attribute :x, Float
      attribute :y, Float
    end

    command "CreateNetArea" do
      attribute :project_id, reference_to("Project")
      attribute :name, String
      attribute :points, list_of("AreaPoint")
      sets locked: true
    end

    command "DeleteNetArea" do
      attribute :net_area_id, reference_to("NetArea")
    end

    command "MoveNetAreaVertex" do
      attribute :net_area_id, reference_to("NetArea")
      attribute :vertex_index, Integer
      attribute :x, Float
      attribute :y, Float
    end

    command "UpdateNetAreaProps" do
      attribute :net_area_id, reference_to("NetArea")
      attribute :name, String
    end
  end

  # When geometry changes, parcels need regeneration
  service "RegenerateParcels" do
    attribute :project_id, String
    call { dispatch("GenerateParcel", project_id: project_id) }
  end
end
