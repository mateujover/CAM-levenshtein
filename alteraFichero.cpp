#include <iostream>
#include <fstream>

// Random functions:
#include <stdlib.h>
#include <time.h>

#define HASH_SIZE 20

using namespace std;


// AUXILIARY FUNCTIONS:
bool not_letter(char c);
bool letter(char c);

// Word error generation:
void swap_letters(char* word, unsigned char i, unsigned char len);
int delete_letter(char* word, unsigned char i, unsigned char len);
//void change_letter(char* word, unsigned char i, unsigned char len);
//int add_letter(char* word, unsigned char i, unsigned char len);


int main()
{
	// Set random seed
	srand( time(NULL) );
	
	// Abrir ficheros:
	//
	string str;
    cout << "Enter name of file: ";
    cin >> str;
    cout << endl;    
    
    ifstream in_file;
    in_file.open(str);
    if (!in_file) {
        cout << "No obert..." << endl;
        return 1;
    }
	
	string str_out;
	str_out = str.substr(0, str.find('.')); // '.' to remove extension
	str_out += "_alt.txt";
	cout << "Resultado en: " << str_out << endl;
    
    ofstream out_file;
    out_file.open(str_out);
    if (!out_file) {
        cout << "No obert (2)..." << endl;
        return 1;
    }
    //
    // Ficheros abiertos y creados
	
	char word[HASH_SIZE];
	unsigned char len, _change, alt_type;	
	char c;
	
	// Initial clear:
	unsigned int iter = 0;
	while ( not_letter(in_file.peek()) && !in_file.eof() )
	{
		c = in_file.get();
		cout << "llegim: " << c << endl;
		out_file.put(c);
		iter++;
	}
	
	//------------ GENERAL LOOP ------------
	//--------------------------------------
	while ( !in_file.eof() && out_file )
	{
		// Tratamiento de palabra:
		//
		len = 0;
		while ( letter(in_file.peek()) && !in_file.eof() && (len < HASH_SIZE) )
		{
			word[len] = in_file.get();
			len++;
		}
		
		if ( ((rand() % 25) == 0)  && (len > 3))
		{ // Si una de las posibilidades 1/256 entonces alteramos la palabra
			_change = rand() % len; // Seleccionar carácter
			alt_type = rand() % 2; // Alterations
			switch (alt_type)
			{
				case 0:
					swap_letters(word, _change, len);
					break;
				case 1:
					len = delete_letter(word, _change, len);
					break;
				/*case 2:
					change_letter(word, _change, len);
					break;
				case 3:
					len = add_letter(word, _change, len);
					break;*/
			}
			out_file.put('*');
		}
		
		// Escribimos la palabra:
		//
		for(unsigned char t = 0; t < len; t++) { out_file.put( word[t] ); }
		// Revision post palabra: puntuaciones y espacios
		//
		while ( not_letter(in_file.peek()) && !in_file.eof() )
		{
			c = in_file.get();
			out_file.put(c);
		}
	}

	in_file.close(); out_file.close();
	cout << endl << "Files closed. Program done. See you" << endl;
	
	return 0;
}




//---------------- AUXILIARY FUNCTIONS ----------------
//

bool not_letter(char c)
{
	if((c >= 'A') && (c <= 'Z')) { return false; }
	
	if((c >= 'a') && (c <= 'z')) { return false; }
	
	if((unsigned char)c > 127) { return false; } // No tenemos signos de puntuacion por encima de 127
	
	return true;
}

bool letter(char c)
{
	return !not_letter(c);
}



//---------------- Word error generation ----------------
//

void swap_letters(char* word, unsigned char i, unsigned char len)
{
	bool utf_0 = (word[i] >= 128);
	if (utf_0 && (word[i] != 0xC3) ) { i--; }
	
	// Comprobaciones para no exceder array:
	if ( utf_0 && (len <= i + 2) )
	{
		if (word[i-1] < 128) { 
			i--;
			utf_0 = false;
		} else {
			i = i - 2;
			utf_0 = true;
		}
	} else if ( !utf_0 && (len <= i + 1) )
	{
		if (word[i-1] < 128) { 
			i--;
			utf_0 = false;
		} else {
			i = i - 2;
			utf_0 = true;
		}
	}
	
	unsigned char d = (utf_0) ? 2 : 1; 
	bool utf_1 = (word[i+d] == 0xC3); // No podria ser sa segona part d'un UTF perque hem decrementat i en cas de que es primer fos UTF8 i l'agafassim desplaçat

	
	if (!utf_0 && !utf_1)
	{
		char aux = word[i];
		word[i] = word[i+1];
		word[i+1] = aux;
	}
	else if (utf_0 && !utf_1)
	{
		char aux = word[i+2];
		word[i+2] = word[i+1];
		word[i+1] = word[i];
		word[i] = aux;
	}
	else if (!utf_0 && utf_1)
	{
		char aux = word[i];
		word[i] = word[i+1];
		word[i+1] = word[i+2];
		word[i+2] = aux;
	}
	else
	{
		char aux[2];
		aux[0] = word[i]; aux[1] = word[i+1];
		word[i] = word[i+2]; word[i+1] = word[i+3];
		word[i+2] = aux[0]; word[i+3] = aux[1];
	}
}

int delete_letter(char* word, unsigned char i, unsigned char len)
{
	if (word[i] >= 128)
	{
		if (word[i] == 0xC3) { i++; }
		// Nos comemos el segundo char UTF-8
		for (unsigned char _i = i; _i + 1 < len; _i++)
			word[_i] = word[_i+1];
		len--; i--;
		// Nos comemos el primer char UTF-8
		for (unsigned char _i = i; _i + 1 < len; _i++)
			word[_i] = word[_i+1];
		len--;	
	}
	else 
	{
		for (unsigned char _i = i; _i + 1 < len; _i++)
			word[_i] = word[_i+1];
		len--;
	}
	return len;
}
/*
void change_letter(char* word, unsigned char i, unsigned char len)
{
	char _new;
	do{
		_new = (rand() % 25) + 97;
	} while(_new != word[i]);
	word[i] = _new;
}

int add_letter(char* word, unsigned char i, unsigned char len)
{
	char save_aux, save = word[i];
	len++;
	change_letter(word, i, len);
	for(unsigned char k = i + 1; k < len; k++)
	{
		save_aux = word[k];
		word[k] = save;
		save = save_aux;
	}	
	return len;
}*/
