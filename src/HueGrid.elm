module HueGrid exposing (gridMeshes)

import Math.Matrix4 as Mat4 exposing (Mat4, scale3, translate3)
import Math.Vector3 as Vec3 exposing (Vec3, vec3)
import Geometry as Geom
    exposing
        ( GeometryObject
        , AppMesh
        , makeColor
        , makeCube
        , indexedTriangleMesh
        )
import Munsell exposing (ColorDict, hueRange, chromaRange, valueRange)


---- CONSTANTS ----


cubeSize : Float
cubeSize =
    40


x0 : Float
x0 =
    80


xySpacing : Float
xySpacing =
    50


zSpacing : Float
zSpacing =
    90



---- HUE GRID CUBES ----


cubesForHue : ColorDict -> Int -> Mat4 -> List GeometryObject
cubesForHue colors hue xf =
    List.foldl (\value acc -> (cubesForHV colors hue value xf) ++ acc) [] valueRange


cubesForHV : ColorDict -> Int -> Int -> Mat4 -> List GeometryObject
cubesForHV colors hue value xf =
    List.foldl
        (\chroma acc ->
            case cubeInGamut colors hue value chroma xf of
                Just grid ->
                    grid :: acc

                Nothing ->
                    acc
        )
        []
        chromaRange


cubeInGamut : ColorDict -> Int -> Int -> Int -> Mat4 -> Maybe GeometryObject
cubeInGamut colors hue value chroma xf =
    case makeColor colors hue value chroma of
        Just color ->
            Just (cubeWithColor color hue value chroma xf)

        Nothing ->
            Nothing


cubeWithColor : Vec3 -> Int -> Int -> Int -> Mat4 -> GeometryObject
cubeWithColor color hue value chroma xf =
    xfCube hue value chroma
        |> Mat4.mul xf
        |> makeCube color


xfCube : Int -> Int -> Int -> Mat4
xfCube _ value chroma =
    let
        x =
            x0 + (toFloat ((chroma // 2) - 1)) * xySpacing

        y =
            (toFloat (value - 5)) * xySpacing
    in
        Mat4.identity
            |> translate3 x y 0
            |> scale3 cubeSize cubeSize cubeSize


type GridLocation
    = GridLeft
    | GridRight


gridMeshes : ColorDict -> Int -> List AppMesh
gridMeshes colors hueRight0 =
    let
        xfRight0 =
            Mat4.identity

        xfRight1 =
            Mat4.translate3 0 0 zSpacing xfRight0

        xfLeft0 =
            Mat4.makeScale3 -1 1 1

        xfLeft1 =
            Mat4.translate3 0 0 zSpacing xfLeft0

        hueRight1 =
            (hueRight0 + 25) % 1000

        hueLeft0 =
            (hueRight0 + 975) % 1000

        hueLeft1 =
            (hueRight0 + 950) % 1000
    in
        [ cubesForHue colors hueRight0 xfRight0 |> indexedTriangleMesh
        , cubesForHue colors hueRight1 xfRight1 |> indexedTriangleMesh
        , cubesForHue colors hueLeft0 xfLeft0 |> indexedTriangleMesh
        , cubesForHue colors hueLeft1 xfLeft1 |> indexedTriangleMesh
        ]
