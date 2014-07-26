local function GenerateCircleVertices( x, y, radius, ang_start, ang_size )

    local vertices = {}
    local passes = 64 -- Seems to look pretty enough
    
    -- Ensure vertices resemble sector and not a chord
    vertices[ 1 ] = { 
        x = x,
        y = y
    }

    for i = 0, passes do

        local ang = math.rad( -90 + ang_start + ang_size * i / passes )

        vertices[ i + 2 ] = {
            x = x + math.cos( ang ) * radius,
            y = y + math.sin( ang ) * radius
        }

    end

    return vertices

end


local RADAR_RADIUS = math.Clamp( math.floor( ScrH() / 7.5 ), 80, 256 )
local RADAR_X, RADAR_Y = RADAR_RADIUS + 32, RADAR_RADIUS + 32
local RADAR_BARSIZE = RADAR_RADIUS / 9
local RADAR_LINESIZE = 3 -- Outline and inline


local inner_vertices = GenerateCircleVertices( RADAR_X, RADAR_Y, RADAR_RADIUS - RADAR_BARSIZE - RADAR_LINESIZE * 2, 0, 360 )
local inner_color = Color( 0, 0, 0, 210 )

local innerline_vertices = GenerateCircleVertices( RADAR_X, RADAR_Y, RADAR_RADIUS - RADAR_BARSIZE - RADAR_LINESIZE, 0, 360 )
local innerline_color = color_black

local bar_vertices = GenerateCircleVertices( RADAR_X, RADAR_Y, RADAR_RADIUS - RADAR_LINESIZE, 0, 360 )
local bar_color = Color( 0, 0, 0, 120 )

local outline_vertices = GenerateCircleVertices( RADAR_X, RADAR_Y, RADAR_RADIUS, 0, 360 )
local outline_color = Color( 0, 0, 0 )

local health_vertices = GenerateCircleVertices( RADAR_X, RADAR_Y, RADAR_RADIUS - RADAR_LINESIZE, 0, 0 )
local health_color =  Color( 102, 165, 96 )
local health_last = 0

local armor_vertices = GenerateCircleVertices( RADAR_X, RADAR_Y, RADAR_RADIUS - RADAR_LINESIZE, 0, 0 )
local armor_color =  Color( 84, 158, 190 )
local armor_last = 0

local tex_white = surface.GetTextureID( "vgui/white" )

local rendering_map = false
local map_rt = GetRenderTarget( "GTARadar!!!", RADAR_RADIUS * 2, RADAR_RADIUS * 2, true )
local map_rt_mat = CreateMaterial( "GTA_Radar!!!", "UnlitGeneric", { ["$basetexture"] = "GTARadar!!!" } )


hook.Add( "HUDPaint", "GTA Radar", function()

	local ply = LocalPlayer()

	if not IsValid( ply ) then

		return

	end

	render.PushFilterMag( TEXFILTER.ANISOTROPIC )
	render.PushFilterMin( TEXFILTER.ANISOTROPIC )

	-- Update health and armor vertices if neccesary
		local health = math.min( ply:Health(), 100 )
		local armor = math.min( ply:Armor(), 100 )
		
		if health ~= health_last or armor ~= armor_last then

			health = Lerp( FrameTime() * 8, health_last, health )
			armor = Lerp( FrameTime() * 8, armor_last, armor )

	        local health_size = 180 * health / 100
	        local armor_size = 180 * armor / 100

			local health_start = 360 - health_size
			local armor_start = health_start - armor_size

			health_vertices = GenerateCircleVertices( RADAR_X, RADAR_Y, RADAR_RADIUS - RADAR_LINESIZE, health_start, health_size )
			armor_vertices = GenerateCircleVertices( RADAR_X, RADAR_Y, RADAR_RADIUS - RADAR_LINESIZE, armor_start, armor_size )

			health_last = health
			armor_last = armor

		end

	-- Render orthographic map to RT
		local old_rt = render.GetRenderTarget()
		local old_w, old_h = ScrW(), ScrH()

		render.SetRenderTarget( map_rt )
			render.SetViewPort( 0, 0, RADAR_RADIUS * 2, RADAR_RADIUS * 2 )

				render.Clear( 0, 0, 0, 0 )

				cam.Start2D()

					local pos = EyePos() + Vector( 0, 0, 100 )
					local ang = Angle( 90, EyeAngles().y, 0 )

					rendering_map = true

						render.RenderView {
							origin = pos,
							angles = ang,
							x = 0,
							y = 0,
							w = RADAR_RADIUS * 2,
							h = RADAR_RADIUS * 2,
							drawviewmodel = false,
							ortho = true,
							ortholeft = -300,
							orthoright = 300,
							orthotop = -300,
							orthobottom = 300
						}

					rendering_map = false

				cam.End2D()

			render.SetViewPort( 0, 0, old_w, old_h )
		render.SetRenderTarget( old_rt )

	-- Bit of stencil wizardry, shit is drawn here
		render.SetStencilEnable( true )

			render.SetStencilReferenceValue( 1 )
			render.SetStencilWriteMask( 1 )
			render.SetStencilTestMask( 1 )

			render.SetStencilPassOperation( STENCIL_REPLACE )
			render.SetStencilFailOperation( STENCIL_KEEP )
			render.SetStencilZFailOperation( STENCIL_KEEP )

			render.ClearStencil()

			render.SetStencilCompareFunction( STENCIL_NOTEQUAL )
				
				surface.SetTexture( tex_white )
				
				surface.SetDrawColor( inner_color )
				surface.DrawPoly( inner_vertices )

			render.SetStencilCompareFunction( STENCIL_EQUAL ) -- Stop drawing from writing to the buffer for our MINIMAP!

				surface.SetMaterial( map_rt_mat )

				surface.DrawTexturedRect( RADAR_X - RADAR_RADIUS, RADAR_Y - RADAR_RADIUS, RADAR_RADIUS * 2, RADAR_RADIUS * 2 )

			render.SetStencilCompareFunction( STENCIL_NOTEQUAL ) -- Resume writing to the buffer on draw

				surface.SetTexture( tex_white )

				surface.SetDrawColor( innerline_color )
				surface.DrawPoly( innerline_vertices )

				surface.SetDrawColor( health_color )
				surface.DrawPoly( health_vertices )

				surface.SetDrawColor( armor_color )
				surface.DrawPoly( armor_vertices )

				surface.SetDrawColor( bar_color )
				surface.DrawPoly( bar_vertices )

				surface.SetDrawColor( outline_color )
				surface.DrawPoly( outline_vertices )

			render.ClearStencil()

		render.SetStencilEnable( false )

	render.PopFilterMag()
	render.PopFilterMin()

end )

hook.Add( "PreDrawSkyBox", "GTA Radar", function()

	if rendering_map then

		return true

	end

end )