module ColorWheel exposing (buildMeshes)

import Dict exposing (Dict)
import WebGL
import Math.Matrix4 as Mat4 exposing (Mat4, scale, translate, rotate)
import Math.Vector3 as Vec3 exposing (Vec3, vec3)
import Geometry
    exposing
        ( Cylinder
        , Cube
        , AppMesh
        , cylinderPoints
        , makeColor
        , makeCube
        , makeCylinder
        , cylinderIndices
        , cubesIndices
        )
import Munsell
    exposing
        ( ColorDict
        , hueRange
        , chromaRange
        , valueRange
        )


---- CONSTANTS ----


cylinderRadius : Float
cylinderRadius =
    90


rSpacing : Float
rSpacing =
    45


cubeSize : Float
cubeSize =
    40


zSpacing : Float
zSpacing =
    90


{-| 280 units
-}
sceneSize : Float
sceneSize =
    cylinderRadius + 10 + (8 * rSpacing)


cubeScaledSize : Float
cubeScaledSize =
    cubeSize / sceneSize


zForValue : Int -> Float
zForValue value =
    toFloat (5 - value) * zSpacing / sceneSize



---- GL OBJECTS ----


wheelCylinder : Int -> Cylinder
wheelCylinder value =
    let
        grayValue =
            (toFloat value) / 10.0

        color =
            vec3 grayValue grayValue grayValue

        xf =
            Mat4.identity
                |> scale (vec3 cubeScaledSize cubeScaledSize cubeScaledSize)
    in
        makeCylinder color xf


wheelCubes : ColorDict -> Int -> List Cube
wheelCubes colors value =
    List.foldl (\hue acc -> (wheelCubesForHue colors hue value) ++ acc) [] hueRange


wheelCubesForHue : ColorDict -> Int -> Int -> List Cube
wheelCubesForHue colors hue value =
    List.foldl
        (\chroma acc ->
            case wheelCube colors hue value chroma of
                Just rect ->
                    rect :: acc

                Nothing ->
                    acc
        )
        []
        chromaRange


wheelCube : ColorDict -> Int -> Int -> Int -> Maybe Cube
wheelCube colors hue value chroma =
    case makeColor colors hue value chroma of
        Just color ->
            xfWheelCube hue value chroma
                |> makeCube color
                |> Just

        Nothing ->
            Nothing


xfWheelCube : Int -> Int -> Int -> Mat4
xfWheelCube hue value chroma =
    let
        theta =
            (toFloat hue) * Basics.pi * (2.0 / 1000.0)

        band =
            toFloat (chroma // 2) - 0.5

        ( sx, sy, sz ) =
            dimColorCube hue value chroma cubeScaledSize

        y =
            (cylinderRadius + 5.0 + (band * rSpacing)) / sceneSize

        z =
            zForValue value
    in
        Mat4.identity
            |> scale (vec3 sx sy sz)
            |> rotate theta (vec3 0 0 1)
            |> translate (vec3 0 y z)


dimColorCube : Int -> Int -> Int -> Float -> ( Float, Float, Float )
dimColorCube _ _ chroma size =
    let
        dx2 =
            case chroma of
                2 ->
                    0.32

                4 ->
                    0.5

                6 ->
                    0.67

                8 ->
                    0.8

                10 ->
                    1

                12 ->
                    1

                _ ->
                    1.33
    in
        ( dx2 * size, size, size )



---- MESHES ----


buildMeshes : ColorDict -> Dict Int AppMesh
buildMeshes colors =
    valueRange
        |> List.map (\value -> ( value, meshForValue colors value ))
        |> Dict.fromList


meshForValue : ColorDict -> Int -> AppMesh
meshForValue colors value =
    let
        cylinder =
            wheelCylinder value

        cubes =
            wheelCubes colors value
    in
        toMesh cylinder cubes


toMesh : Cylinder -> List Cube -> AppMesh
toMesh cylinder cubes =
    WebGL.indexedTriangles
        (List.concat (cylinder :: cubes))
        (List.concat
            [ cylinderIndices 0
            , cubesIndices cylinderPoints cubes
            ]
        )
