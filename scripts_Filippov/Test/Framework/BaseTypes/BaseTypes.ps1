# object state saver/loader definition
$ObjectStateDefinition =  @'
using System;
using System.Collections.Generic;
using System.Reflection;
using System.Text;
using System.Xml;
using System.IO;
using System.Xml.Serialization;

	public class ObjectState
    {
        
        private readonly Dictionary<Type, XmlSerializer> serializers =
            new Dictionary<Type, XmlSerializer>();
        
        private XmlSerializer CheckType(Type serializedType)
        {
            XmlSerializer result;
            if (!serializers.TryGetValue(serializedType, out result))
            {
                result = new XmlSerializer(serializedType);
                serializers[serializedType] = result;
            }
            return result;
        }

        #region Save Object
		public void SaveObject(string fileName, object savedObject)
        {
            SaveObjectState(fileName, savedObject);
        }

        private bool SaveObjectState<T>(string fileName, T savedObject)
        {
            try
            {
                var serializer = CheckType(savedObject.GetType());
                using (var fs = new FileStream(fileName, FileMode.Create))
                {
                    serializer.Serialize(fs, savedObject);
                }
                return true;
            }
            catch (Exception e)
            {
                //Log.LogError(e);
                return false;
            }
        }
        #endregion

        #region Load Object
		public Object LoadObject(string fileName, Type type)
        {
            object resObj;
            var res = LoadObjectState(fileName, type, out resObj);
            return resObj;
        }

        private bool LoadObjectState<T>(string fileName, Type restoredObjectType,
            out T restoredObject)
        {
            return LoadObject(fileName, restoredObjectType, out restoredObject);
        }

        private bool LoadObject<T>(string fileName, Type restoredObjectType,
            out T restoredObject)
        {
            restoredObject = default(T);
            if (!File.Exists(fileName))
                return false;

            FileStream fs = null;
            try
            {
                XmlSerializer serializer = CheckType(restoredObjectType);
                fs = new FileStream(fileName, FileMode.Open, FileAccess.Read);
                restoredObject = (T)serializer.Deserialize(fs);
                return true;
            }
            catch (Exception e)
            {
                //Log.LogError(e);
                return false;
            }
            finally
            {
                if (fs != null)
                    fs.Close();
            }
        }
        #endregion
    }
'@
Add-Type -TypeDefinition $ObjectStateDefinition -ReferencedAssemblies @("System.Xml") -Language Csharp -IgnoreWarnings:$true

#$refPath = (get-location).Path + "\TestFramework.dll"
#Add-Type @"
#    using System;
#	
#	public class Agent
#    {
#        public string Name;
#		public string User;
#		public string Password;
#		public string Roles;		
#    }
#
#"@ -OutputAssembly $refPath
#Add-Type -Path $refPath
#