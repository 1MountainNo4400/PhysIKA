#pragma once

#include "CollisionMesh.h"
//#include "Dynamics/RigidBody/TriangleMesh.h"

namespace PhysIKA {

	struct CollisionDate {
		CollisionDate(CollisionMesh* m, bool flag) 
			: ms(m), enable_selfcollision(flag) { }
		CollisionMesh* ms;
		bool enable_selfcollision;
	};

	//struct CollisionDate {
	//	CollisionDate(std::shared_ptr<TriangleMesh<float>> m, bool flag) 
	//		: ms(m), enable_selfcollision(flag) { }
	//	std::shared_ptr<TriangleMesh<float>> ms;
	//	bool enable_selfcollision;
	//};

	struct ImpactInfo
	{
		ImpactInfo(int fid1, int fid2, int vf_ee, int v, int v2, int v3, int v4, float d, float t, int CCD)
		{
			f_id[0] = fid1;
			f_id[1] = fid2;

			IsVF_OR_EE = vf_ee;

			vertex_id[0] = v;
			vertex_id[1] = v2;
			vertex_id[2] = v3;
			vertex_id[3] = v4;

			dist = d;
			time = t;

			CCDres = CCD;
		}

		int f_id[2]; //��Ƭid

		//0:vf  1:ee
		int IsVF_OR_EE;

		int vertex_id[4];

		float dist;
		float time;

		int CCDres;
	};

}