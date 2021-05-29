#pragma once

#include "Dynamics/RigidBody/TriangleMesh.h"
#include "CollidableTriangle.h"
#include "CollisionMesh.h"
#include "CollisionBVH.h"
#include "CollisionDate.h"

#include <iostream>
#include <vector>


namespace PhysIKA {
	class Collision {
	public:
		using MeshPair = std::pair<int, int>;


		~Collision() {
			for (int i = 0; i < dl_mesh.size(); i++) {
				delete dl_mesh[i];
			}
		}

		//���ú����ӿڣ������ڲ���ײ����㷨
		void collid();

		//��ײ������ӿ�
		void transformPair(unsigned int a, unsigned int b);

		//ģ����������ӿڣ�����ģ������ĵ㼯���漯
		void transformMesh(unsigned int numVtx, unsigned int numTri, 
			std::vector<unsigned int> tris,
			std::vector<float> vtxs,
			std::vector<float> pre_vtxs,
			int m_id, bool able_selfcollision = false
		);
		void transformMesh(unsigned int numVtx, unsigned int numTri, 
			std::vector<unsigned int> tris,
			std::vector<vec3f> vtxs,
			std::vector<vec3f> pre_vtxs,
			int m_id, bool able_selfcollision = false
		);
		void transformMesh(TriangleMesh<DataType3f> mesh,
			int m_id, bool able_selfcollision = false
		);

		//����ӿڣ����ط�����ײ��ģ���������������Ƭ�ļ���
		std::vector<std::vector<TrianglePair> > getContactPairs() { return contact_pairs; }

		//����ӿڣ����ط�����ײ����ײ������
		int getNumContacts() { return contact_pairs.size(); }

		//����ӿڣ�������ײ�Է�����ײ��ʱ��
		//vector<float> getContactTimes() { return contact_time; }

		//����CCD�����1���д�͸  0���޴�͸
		int getCCD_res() { return CCDtime; }

		//���ú��
		void setThickness(float tt) { thickness = tt; }

		//������ײ��Ϣ
		std::vector<ImpactInfo> getImpactInfo() { return contact_info; }

		static Collision* getInstance()
		{
			if (instance == NULL) {
				instance = new Collision();
				return instance;
			}
			else
				return instance;
		}


		static Collision* instance;

	private:
		Collision() = default;

	private:
		std::vector<CollisionDate> bodys;
		std::vector<MeshPair> mesh_pairs;
		std::vector<std::vector<TrianglePair>> contact_pairs;
		std::vector<CollisionMesh*> dl_mesh;//delete mesh points
		std::vector<ImpactInfo> contact_info;
		int CCDtime = 0;
		float thickness = 0.0f;
	};
}