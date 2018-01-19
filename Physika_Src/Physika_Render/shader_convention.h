/*
 * @file shader_convention.h 
 * @Brief shader convention
 * @author: Wei Chen
 * 
 * This file is part of Physika, a versatile physics simulation library.
 * Copyright (C) 2013- Physika Group.
 *
 * This Source Code Form is subject to the terms of the GNU General Public License v2.0. 
 * If a copy of the GPL was not distributed with this file, you can obtain one at:
 * http://www.gnu.org/licenses/gpl-2.0.html
 *
 */

#pragma once

/*
���ĵ�����������shader�й������ݽṹ�Ͳ��ֵ���Ӧ��Լ�����������ϸ����ش˹�Լ������ȷ��shader�������ݡ�

------------------------------------------------------------------------------------------------------
�������ԣ�

layout (location = 0) in vec3 vert_pos;          //����λ��
layout (location = 1) in vec3 vert_normal;       //���㷨��
layout (location = 2) in vec2 vert_tex_coord;    //������������
layout (location = 3) in vec3 vert_col;          //������ɫ 
layout (location = 4) in vec3 vert_vector;       //�����Զ�������

layout (location = 5) in float density;          //�����ܶ�
layout (location = 6) in int phase;              //����phase

------------------------------------------------------------------------------------------------------
�������

ͶӰ����
uniform mat4 proj_trans;

��ͼ����:
uniform mat4 view_trans;

ģ�;���:
uniform mat4 model_trans;

�۲�λ��:
uniform vec3 view_pos;

------------------------------------------------------------------------------------------------------

��Դ��

struct DirectionalLight
{
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
    
    vec3 direction;
};


struct PointLight
{
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;

    vec3 pos;
    float constant_atten;
    float linear_atten;
    float quadratic_atten;
};

struct SpotLight
{
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;

    vec3 pos;
    float constant_atten;
    float linear_atten;
    float quadratic_atten;

    vec3 spot_direction;
    float spot_exponent; //need further consideration
    float spot_cutoff; //in radians
};

uniform int directional_light_num = 0;
uniform DirectionalLight[5] directional_lights;

uniform int point_light_num = 0;
uniform PointLight point_lights[5];

uniform int spot_light_num = 0;
uniform SpotLight spot_lights[5];

------------------------------------------------------------------------------------------------------

���ʣ�

struct Material
{
    vec3 Ka;
    vec3 Kd;
    vec3 Ks;
    float shininess;
    float alpha;
};

Material material;

------------------------------------------------------------------------------------------------------

����

uniform bool use_tex;
uniform bool has_tex;
uniform sampler2D tex; //texture unit 0

------------------------------------------------------------------------------------------------------

��Ӱ��

�۹����Ӱ��

struct SpotLightShadowMap
{
    mat4 light_trans; 
    sampler2D shadow_map_tex;
};

uniform bool use_shadow_map;
uniform SpotLightShadowMap spot_light_shadow_maps[5];

------------------------------------------------------------------------------------------------------

��ɫ��

uniform vec3 col; //��ɫ

uniform bool use_solid_col;
uniform vec3 solid_col;

uniform bool use_custom_col;  //��Ӧ�������� layout (location = 3) in vec3 vert_col; 


*/