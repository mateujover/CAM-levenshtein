#include <iostream>
#include <map>
#include <string>
#include <fstream>
#include <cctype>
#include <cstring>

using namespace std;

int main (int argc, char** argv)
{
	if(strcmp(setlocale(LC_ALL, NULL), "C") == 0)
	{
		cout << "Tenim encoding 'C'. Canvi a nes des sistema..." << endl;
		if(setlocale(LC_ALL, "") == NULL)
		{
			cout << "Failed to set new locale\nEXIT";
			return 1;
		}
	}
	
	typedef map<string, unsigned int> dictionary_t;
	
	string str;
    cout << "File to extract dictionary: ";
    cin >> str;
    cout << endl;
    
    ifstream in_file;
    in_file.open(str.c_str(), ifstream::in);
    str.clear();
    if (!in_file)
    {
        cout << "Fallo obrint fitxer quijote..." << endl;
        return 1;
    }
    cout << "Ok fitxer" << endl;
    unsigned short w_len = 0;
    dictionary_t diccionari;
    char c = ' ';
    unsigned int palabra = 0;
    // Limpiamos inicio de fichero:
    cout << "Reading file..." << endl;
    cout << "debug: " << in_file.get() << endl;
    while (!in_file.eof() && in_file.good())
    {
        while ( isalpha(in_file.peek()) || in_file.peek() == '-' )
        {
            in_file >> c;
            str += c;
        }
		if (diccionari.find(str) == diccionari.end())
		{ // Todo el diccionario recorrido:
		    diccionari.insert( pair<string, unsigned int>(str, palabra) );
		    palabra++;
            if(w_len < str.length())
                w_len = str.length();
	    }
        while ( !isalpha(in_file.peek()) && !in_file.eof() ) { in_file >> c; }
        str.clear();
        //str += c;
    }
    
    cout << "Creamos fichero de salida. Introduzca nombre del fichero: " << endl;
    cin >> str;
    str += ".txt";
    ofstream out_file;
    out_file.open(str.c_str());
    str.clear();
    if (!out_file)
    {
    	cout << "Fallo fichero de salida" << endl;
    	return 1;
    }
    unsigned int l = 0;
    cout << "Escribimos en fichero de salida" << endl;
    for(dictionary_t::iterator entrada = diccionari.begin(); entrada != diccionari.end(); entrada++, l++)
    {
    	out_file << (entrada->first) << endl;
    }
    
    in_file.close(); out_file.close();
    cout << "HASH_SIZE recomendado: " << w_len << endl;
    cout << "Longitud de entradas: " << l << endl;
    cout << "Final de programa" << endl;
    return 0;
}
