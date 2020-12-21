#include <iostream>
#include <fstream>

using namespace std;

int main()
{
    ifstream in_file;
    in_file.open("the_king_james_bible.txt");
    if (!in_file) {
        cout << "No obert..." << endl;
        return 1;
    }

    ofstream out_file;
    out_file.open("kingjamesbible.txt");
    if (!out_file) {
        cout << "No obert segon..." << endl;
        return 1;
    }

    char ch;

    while ( !in_file.eof() && !in_file.fail() && !out_file.fail() )
    {
        in_file.get(ch);
        if(ch < 128) 
        { 
            if ( (ch >= 'A') && (ch <= 'Z') ) 
                ch = ch | 0x20;
            out_file.put(ch); // Forzado de minusculas
        }
        else if (ch == 0xC3)
        {
            out_file.put(ch);
            in_file.get(ch);
            out_file.put( (ch | 0x20) ); // Suponemos que solo tenemos vocales y ñ
        }
        else {
            cout << "Error de cribratge. Valor char: "<< (unsigned int) ch << endl;
        }
    }
    
    if(in_file.bad()){
        cout << "Error lectura in_file" << endl;
    }
    if (out_file.bad())
    {
        cout << "Error escritura out_file" << endl;
    }
    out_file.close(); in_file.close();
    cout << endl << "Files closed. Fin de programa" << endl;
    return 0;
}