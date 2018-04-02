module ColorWheel exposing (..)

import Dict exposing (Dict)
import Math.Matrix4 as Mat4 exposing (Mat4, scale3, translate3, rotate)
import Math.Vector3 as Vec3 exposing (Vec3, vec3)
import Geometry as Geom
    exposing
        ( Solid
        , AppMesh
        , cylinderPoints
        , makeColor
        , makeCube
        , makeCylinder
        , toMesh
        )
import Munsell
    exposing
        ( ColorDict
        , hueRange
        , chromaRange
        , valueRange
        )


---- CONSTANTS ----


cylinderSize : Float
cylinderSize =
    80


cubeSize : Float
cubeSize =
    40


r0 : Float
r0 =
    (cylinderSize / 2) + 10 + (cubeSize / 2)


rSpacing : Float
rSpacing =
    50


sceneSize : Float
sceneSize =
    r0 + (8 * rSpacing) + (cubeSize / 2)


zSpacing : Float
zSpacing =
    90


zForValue : Int -> Float
zForValue value =
    toFloat (value - 5) * zSpacing



---- GL OBJECTS ----


cylinderForValue : Int -> Solid
cylinderForValue value =
    let
        grayValue =
            (toFloat value) / 10.0

        color =
            vec3 grayValue grayValue grayValue
    in
        makeCylinder color (xfCylinder value)


xfCylinder : Int -> Mat4
xfCylinder value =
    let
        z =
            zForValue value
    in
        Mat4.identity
            |> translate3 0 0 z
            |> scale3 cylinderSize cylinderSize cubeSize


cubesForValue : ColorDict -> Int -> List Solid
cubesForValue colors value =
    List.foldl (\hue acc -> (cubesForHV colors hue value) ++ acc) [] hueRange


cubesForHV : ColorDict -> Int -> Int -> List Solid
cubesForHV colors hue value =
    List.foldl
        (\chroma acc ->
            case cubeInGamut colors hue value chroma of
                Just rect ->
                    rect :: acc

                Nothing ->
                    acc
        )
        []
        chromaRange


cubeInGamut : ColorDict -> Int -> Int -> Int -> Maybe Solid
cubeInGamut colors hue value chroma =
    case makeColor colors hue value chroma of
        Just color ->
            Just (cubeWithColor color hue value chroma)

        Nothing ->
            Nothing


cubeWithColor : Vec3 -> Int -> Int -> Int -> Solid
cubeWithColor color hue value chroma =
    xfCube hue value chroma
        |> makeCube color


xfCube : Int -> Int -> Int -> Mat4
xfCube hue value chroma =
    let
        theta =
            (toFloat hue) * 2 * Basics.pi / 1000

        ( sx, sy, sz ) =
            scaleCube hue value chroma cubeSize

        band =
            (chroma // 2) - 1

        y =
            r0 + ((toFloat band) * rSpacing)

        z =
            zForValue value
    in
        Mat4.identity
            |> rotate -theta (vec3 0 0 1)
            |> translate3 0 y z
            |> scale3 sx sy sz



-- |> translate (vec3 0 y z)
-- |> rotate theta (vec3 0 0 1)


scaleCube : Int -> Int -> Int -> Float -> ( Float, Float, Float )
scaleCube _ _ chroma size =
    let
        x =
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
        ( (x * size), size, size )



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
            cylinderForValue value

        cubes =
            cubesForValue colors value
    in
        toMesh (cylinder :: cubes)
