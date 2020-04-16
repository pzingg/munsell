module Geometry exposing (..)

import WebGL exposing (Mesh)
import Math.Matrix4 as Mat4 exposing (Mat4, transform, translate, rotate)
import Math.Vector3 as Vec3 exposing (Vec3, vec3)
import Munsell exposing (ColorDict, findColor)


{-| World Coordinate System - Cartesian

  - positive x to right
  - positive y is up
  - positive z coming out towards camera

Camera (Eye) Coordinates - Radial

  - theta is vertical angle (positive y) between camera position and z axis,
    with -0.5 * pi <= theta <= 0.5 * pi, 0 <= cos theta <= 1, -1 <= sin theta <= 1
  - phi is horizontal angle (positive x) between camera position and z axis, 0 <= phi < 2 * pi

-}
worldUp : Vec3
worldUp =
    Vec3.j


worldCenter : Vec3
worldCenter =
    vec3 0 0 0



---- WEBGL TYPES ----


type alias Color =
    Vec3


type alias Vertex =
    { position : Vec3
    , color : Color
    }


type alias AppMesh =
    Mesh Vertex


type alias Camera =
    { position : Vec3
    , phi : Float
    }


{-| Perform [modular arithmetic](https://en.wikipedia.org/wiki/Modular_arithmetic)
involving floating point numbers.
The sign of the result is the same as the sign of the `modulus`
in `fractionalModBy modulus x`.
    fractionalModBy 2.5 5 --> 0
    fractionalModBy 2 4.5 == 0.5
    fractionalModBy 2 -4.5 == 1.5
    fractionalModBy -2 4.5 == -1.5
-}
fractionalModBy : Float -> Float -> Float
fractionalModBy modulus x =
    x - modulus * toFloat (floor (x / modulus))


makeCamera : Float -> Float -> Float -> Camera
makeCamera cameraDistance theta phi =
    { position =
        vec3
            (cameraDistance * cos theta * sin phi)
            (cameraDistance * sin theta)
            (cameraDistance * cos theta * cos phi)
    , phi = fractionalModBy (2 * pi) phi
    }


dragCamera : Float -> Float -> Float -> Camera -> Camera
dragCamera cameraDistance deltaX deltaY { position, phi } =
    let
        radPerPixel =
            pi / cameraDistance

        -- deltaY positive is down in view coordinate system
        -- so negate to transfer to x for world coordinates
        deltaTheta =
            -radPerPixel * deltaY

        -- deltaX positive is right in view coordinate system
        -- so transfer to y for world coordinates
        deltaPhi =
            radPerPixel * deltaX

        currentTheta =
            Vec3.normalize position
                |> Vec3.getY
                |> asin

        -- Subtract deltaTheta and deltaPhi
        theta =
            (currentTheta - deltaTheta)
                |> (Basics.max (-0.5 * pi))
                |> (Basics.min (0.5 * pi))
    in
        makeCamera cameraDistance theta (phi - deltaPhi)


{-| camera.position positive y: { 0 = 0, 1 = 5240, 2 = 0 }
camera.position near positive y: { position = { 0 = 0, 1 = 5239.999997414164, 2 = 0.16461945502184888 }, phi = 0 }
lookAt positive y: { 0 = NaN, 1 = NaN, 2 = 0, 3 = 0, 4 = NaN, 5 = NaN, 6 = 1, 7 = 0, 8 = NaN, 9 = NaN, 10 = 0, 11 = 0, 12 = NaN, 13 = NaN, 14 = -5240, 15 = 1 }
lookAt near positive y:
{ 0 = 1, 1 = 0, 2 = 0, 3 = 0
, 4 = 0, 5 = 0.0000314159265308872, 6 = 0.9999999995065197, 7 = 0
, 8 = 0, 9 = -0.99999999950652, 10 = 0.00003141592653088719, 11 = 0
, 12 = 0, 13 = 0, 14 = -5240, 15 = 1 }

camera.position negative y: { 0 = 0, 1 = -5240, 2 = 0 }
camera.position near negative y: { position = { 0 = 0, 1 = -5239.999997414164, 2 = 0.16461945502184888 }, phi = 0 }
lookAt negative y: { 0 = NaN, 1 = NaN, 2 = 0, 3 = 0, 4 = NaN, 5 = NaN, 6 = -1, 7 = 0, 8 = NaN, 9 = NaN, 10 = 0, 11 = 0, 12 = NaN, 13 = NaN, 14 = -5240, 15 = 1 }
lookAt near negative y:
{ 0 = 1, 1 = 0, 2 = 0, 3 = 0
, 4 = 0, 5 = 0.0000314159265308872, 6 = -0.9999999995065197, 7 = 0
, 8 = 0, 9 = 0.99999999950652, 10 = 0.00003141592653088719, 11 = 0
, 12 = 0, 13 = 0, 14 = -5240, 15 = 1 }

-}
cameraMatrix : Camera -> Mat4
cameraMatrix { position, phi } =
    let
        cameraDistance =
            Vec3.length position

        normal =
            Vec3.normalize position

        dot =
            Vec3.dot normal worldUp
    in
        case dot > 0.99999 of
            True ->
                Mat4.fromRecord
                    { m11 = 1
                    , m21 = 0
                    , m31 = 0
                    , m41 = 0
                    , m12 = 0
                    , m22 = 0
                    , m32 = 1
                    , m42 = 0
                    , m13 = 0
                    , m23 = -1
                    , m33 = 0
                    , m43 = 0
                    , m14 = 0
                    , m24 = 0
                    , m34 = -cameraDistance
                    , m44 = 1
                    }
                    |> Mat4.rotate -phi Vec3.j

            False ->
                case dot < -0.99999 of
                    True ->
                        Mat4.fromRecord
                            { m11 = 1
                            , m21 = 0
                            , m31 = 0
                            , m41 = 0
                            , m12 = 0
                            , m22 = 0
                            , m32 = -1
                            , m42 = 0
                            , m13 = 0
                            , m23 = 1
                            , m33 = 0
                            , m43 = 0
                            , m14 = 0
                            , m24 = 0
                            , m34 = -cameraDistance
                            , m44 = 1
                            }
                            |> Mat4.rotate -phi Vec3.j

                    False ->
                        Mat4.makeLookAt position worldCenter worldUp


type alias Uniforms =
    { perspective : Mat4
    , camera : Mat4
    }


makeUniforms : Float -> Float -> Float -> Camera -> Uniforms
makeUniforms width height worldSize camera =
    { perspective = Mat4.makePerspective 22 (width / height) 0.01 (worldSize * 4)
    , camera = cameraMatrix camera
    }


{-| A GeometryObject is made up of vertices.
A Cube has 4 corner points (top face) and 4 on the bottom face = 8 total.
A Cylinder has 1 center point plus 'cylinderFacePoints' on the circumference
of both the top and bottom faces.
-}
type ObjectType
    = Cube
    | Cylinder
    | Polyline


type alias GeometryObject =
    { type_ : ObjectType
    , vertices : List Vertex
    }


getVertices : GeometryObject -> List Vertex
getVertices { vertices } =
    vertices


getVertexIndices : Int -> GeometryObject -> List ( Int, Int, Int )
getVertexIndices base { type_, vertices } =
    case type_ of
        Cube ->
            cubeIndices base

        Cylinder ->
            cylinderIndices base

        _ ->
            []



---- COLORS ----


type alias BallColors =
    { xPos : Color
    , xNeg : Color
    , yPos : Color
    , yNeg : Color
    , oPos : Color
    , oNeg : Color
    }


defaultBallColors : BallColors
defaultBallColors =
    { xPos = vec3 1 0 0
    , xNeg = vec3 0 1 0
    , yPos = vec3 1 1 0
    , yNeg = vec3 0 1 1
    , oPos = vec3 0 0 1
    , oNeg = vec3 1 0 1
    }


makeColor : ColorDict -> Int -> Int -> Int -> Maybe Color
makeColor colors hue value chroma =
    case findColor colors hue value chroma of
        Ok mc ->
            Just <| vec3 mc.red mc.green mc.blue

        Err err ->
            Nothing



---- INDEXED TRIANGLE OBJECTS ----


indexedTriangleMesh : List GeometryObject -> AppMesh
indexedTriangleMesh objects =
    let
        ( v, i ) =
            buildTriangleIndices objects
    in
        WebGL.indexedTriangles v i


buildTriangleIndices : List GeometryObject -> ( List Vertex, List ( Int, Int, Int ) )
buildTriangleIndices objects =
    List.foldl
        (\object ( accv, acci ) ->
            case object.type_ of
                Polyline ->
                    ( accv, acci )

                _ ->
                    let
                        base =
                            List.length accv
                    in
                        ( List.append accv (getVertices object)
                        , List.append acci (getVertexIndices base object)
                        )
        )
        ( [], [] )
        objects



---- CYLINDERS ----


cylinderFacePoints : Int
cylinderFacePoints =
    16


cylinderPoints : Int
cylinderPoints =
    2 * (cylinderFacePoints + 1)


cylinderFaceVertex : Color -> Mat4 -> Float -> Int -> Vertex
cylinderFaceVertex color xf y i =
    let
        t =
            pi * (toFloat ((i - 1) * 2)) / (toFloat cylinderFacePoints)
    in
        Vertex (transform xf (vec3 (0.5 * sin t) y (0.5 * cos t))) color


makeCylinder : Color -> Mat4 -> GeometryObject
makeCylinder color xf =
    let
        topFace =
            List.range 1 cylinderFacePoints
                |> List.map (cylinderFaceVertex color xf 0.5)

        bottomFace =
            List.range 1 cylinderFacePoints
                |> List.map (cylinderFaceVertex color xf -0.5)
    in
        List.concat
            [ Vertex (transform xf (vec3 0 0.5 0)) color :: topFace
            , Vertex (transform xf (vec3 0 -0.5 0)) color :: bottomFace
            ]
            |> GeometryObject Cylinder


cylinderIndices : Int -> List ( Int, Int, Int )
cylinderIndices base =
    let
        top =
            List.range 1 cylinderFacePoints
                |> List.map
                    (\i ->
                        ( base
                        , base + i
                        , if i < cylinderFacePoints then
                            base + i + 1
                          else
                            base + 1
                        )
                    )

        sides =
            List.range 1 cylinderFacePoints
                |> List.map
                    (\i ->
                        if i < cylinderFacePoints then
                            [ ( base + i
                              , base + i + cylinderFacePoints + 1
                              , base + i + cylinderFacePoints + 2
                              )
                            , ( base + i + cylinderFacePoints + 2
                              , base + i + 1
                              , base + i
                              )
                            ]
                        else
                            [ ( base + cylinderFacePoints
                              , base + 2 * cylinderFacePoints + 1
                              , base + cylinderFacePoints + 2
                              )
                            , ( base + cylinderFacePoints + 2
                              , base + 1
                              , base + cylinderFacePoints
                              )
                            ]
                    )
                |> List.concat

        bottom =
            List.range (cylinderFacePoints + 1) (2 * cylinderFacePoints + 1)
                |> List.reverse
                |> List.map
                    (\i ->
                        ( base + cylinderFacePoints + 1
                        , base + i
                        , if i > cylinderFacePoints then
                            base + i - 1
                          else
                            base + 2 * cylinderFacePoints + 1
                        )
                    )
    in
        List.concat [ top, sides, bottom ]



---- CUBES ----


cubePoints : Int
cubePoints =
    8


cubeVertexOrder : List ( Int, Int, Int )
cubeVertexOrder =
    [ -- front
      ( 0, 1, 2 )
    , ( 2, 3, 0 )
    , -- right
      ( 1, 5, 6 )
    , ( 6, 2, 1 )
    , -- back
      ( 7, 6, 5 )
    , ( 5, 4, 7 )
    , -- left
      ( 4, 0, 3 )
    , ( 3, 7, 4 )
    , -- bottom
      ( 4, 5, 1 )
    , ( 1, 0, 4 )
    , -- top
      ( 3, 2, 6 )
    , ( 6, 7, 3 )
    ]


makeCube : Color -> Mat4 -> GeometryObject
makeCube color xf =
    [ Vertex (transform xf (vec3 -0.5 -0.5 0.5)) color
    , Vertex (transform xf (vec3 -0.5 0.5 0.5)) color
    , Vertex (transform xf (vec3 0.5 0.5 0.5)) color
    , Vertex (transform xf (vec3 0.5 -0.5 0.5)) color
    , Vertex (transform xf (vec3 -0.5 -0.5 -0.5)) color
    , Vertex (transform xf (vec3 -0.5 0.5 -0.5)) color
    , Vertex (transform xf (vec3 0.5 0.5 -0.5)) color
    , Vertex (transform xf (vec3 0.5 -0.5 -0.5)) color
    ]
        |> GeometryObject Cube


cubeIndices : Int -> List ( Int, Int, Int )
cubeIndices base =
    cubeVertexOrder
        |> List.map
            (\( v1, v2, v3 ) ->
                ( base + v1, base + v2, base + v3 )
            )



---- POLYLINE OBJECTS ----


polylineMeshes : List GeometryObject -> List AppMesh
polylineMeshes objects =
    List.foldl
        (\object acc ->
            case object.type_ of
                Polyline ->
                    WebGL.lineStrip (getVertices object) :: acc

                _ ->
                    acc
        )
        []
        objects


makeWireframeBall : BallColors -> Mat4 -> List GeometryObject
makeWireframeBall colors xf =
    equator colors.xPos colors.xNeg xf
        :: segment colors.yPos colors.yNeg 0 xf
        :: (List.range 1 ((cylinderFacePoints // 2) - 1)
                |> List.map
                    (\i ->
                        let
                            angle =
                                (toFloat i) * 2 * pi / (toFloat cylinderFacePoints)
                        in
                            segment colors.oPos colors.oNeg angle xf
                    )
           )
        |> List.concat


equator : Color -> Color -> Mat4 -> List GeometryObject
equator colorPos colorNeg xf =
    let
        posHalf =
            List.range 0 (cylinderFacePoints // 2)
                |> List.map
                    (\i ->
                        let
                            theta =
                                (toFloat i) * 2 * pi / (toFloat cylinderFacePoints)
                        in
                            Vertex (transform xf (vec3 (0.5 * sin theta) 0 (0.5 * cos theta))) colorPos
                    )
                |> GeometryObject Polyline

        negHalf =
            List.range (cylinderFacePoints // 2) cylinderFacePoints
                |> List.map
                    (\i ->
                        let
                            theta =
                                (toFloat i) * 2 * pi / (toFloat cylinderFacePoints)
                        in
                            Vertex (transform xf (vec3 (0.5 * sin theta) 0 (0.5 * cos theta))) colorNeg
                    )
                |> GeometryObject Polyline
    in
        [ posHalf, negHalf ]


segment : Color -> Color -> Float -> Mat4 -> List GeometryObject
segment colorPos colorNeg angle xf =
    let
        posHalf =
            List.range 0 (cylinderFacePoints // 2)
                |> List.map
                    (\i ->
                        let
                            theta =
                                (toFloat i) * 2 * pi / (toFloat cylinderFacePoints)

                            xf_ =
                                Mat4.rotate angle worldUp xf
                        in
                            Vertex (transform xf_ (vec3 (0.5 * cos theta) (0.5 * sin theta) 0)) colorPos
                    )
                |> GeometryObject Polyline

        negHalf =
            List.range (cylinderFacePoints // 2) cylinderFacePoints
                |> List.map
                    (\i ->
                        let
                            theta =
                                (toFloat i) * 2 * pi / (toFloat cylinderFacePoints)

                            xf_ =
                                Mat4.rotate angle worldUp xf
                        in
                            Vertex (transform xf_ (vec3 (0.5 * cos theta) (0.5 * sin theta) 0)) colorNeg
                    )
                |> GeometryObject Polyline
    in
        [ posHalf, negHalf ]
