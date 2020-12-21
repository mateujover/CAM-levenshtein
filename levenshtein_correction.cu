#include <fstream>
#include <iostream>
#include <string>
#include <clocale>
#include <cctype>

#define HASH_SIZE 20
#define PADDING_CHAR '\0'

//Macro extaida de exemplos de NVIDIA: modificado printf -> cout
#define CUDA_CALL(x) do { if((x) != cudaSuccess) { \
    cout << "Error at " << __FILE__ << " line: " << __LINE__ << endl; \
    return EXIT_FAILURE;}} while(0)

using namespace std;

// Definimos una funcion minimo por si CUDA/C++ no lo incluye para GPU
__device__ unsigned short my_strlen(char *s)
{
	unsigned short len = 0;
	while(len < HASH_SIZE && s[len] != PADDING_CHAR) { len++; }
	return len;
}

__device__ unsigned short minimo(unsigned short a, unsigned short b){
	if(a > b)
		return b;
	else
		return a;
}

__device__ unsigned short lev_dist(char *s1, char *s2){
	unsigned short l1, l2, i, j, c, res, w;
    l1 = my_strlen(s1);
    l2 = my_strlen(s2);
	// Verifica que exista algo que comparar
    if (l1 == 0) return(l2);
    if (l2 == 0) return(l1);
    w = l1 + 1;
	// Reserva matriz con malloc: m[i,j] = m[j*w+i] !!
    unsigned short m[((HASH_SIZE+1)*HASH_SIZE+1) + HASH_SIZE+1];
	// Rellena primera fila y primera columna
    for (i = 0; i <= l1; i++) m[i] = i;
    for (j = 0; j <= l2; j++) m[j*w] = j;
	// Recorremos resto de la matriz llenando pesos
    for (i = 1; i <= l1; i++){
		for (j = 1; j <= l2; j++)
		{ 
			if (s1[i-1] == s2[j-1]) 
				c = 0;
			else 
				c = 1;
			
		    m[j*w+i] = minimo(minimo(m[j*w+i-1]+1, m[(j-1)*w+i]+1), m[(j-1)*w+i-1]+c);
		}
	}
	// Devolvemos esquina final de la matriz
    res = m[l2*w+l1];
    return(res);
}

/*----------------------------------------------------------------------------
  ----------------------------------------------------------------------------
  -----------------------  GLOBAL FUNCTIONS: KERNELS  ------------------------
  ----------------------------------------------------------------------------
  ----------------------------------------------------------------------------*/

__global__ void k_setupPadding(char *first_word, unsigned int total_entradas, char _padd = (char)PADDING_CHAR){
	
	unsigned int idx = threadIdx.x + (blockDim.x * blockIdx.x);
	unsigned int stride = blockDim.x * gridDim.x;
	
	while(idx < total_entradas){ // Aqui direccionamos de caracter en caracter
		for(unsigned char _off = 0; _off < HASH_SIZE; _off++){
			first_word[(idx * HASH_SIZE) + _off] = _padd;
		}
		idx += stride;
	}
	
}

__global__ void k_levenshtein(char *str, char *first_word, unsigned int total_entradas, unsigned int *out_idx, unsigned short *out_dist)
{
	char local_str[HASH_SIZE];
	// Bottleneck
	for(unsigned char i = 0; i < HASH_SIZE; i++) {
		local_str[i] = str[i];
	}
	// Para copiar de vuelta en CPU
	unsigned short local_min = 0xFFFF;
	unsigned int min_idx = 0;
	// Limites e indices
	unsigned int idx = threadIdx.x + (blockDim.x * blockIdx.x); // Id para stride 0
	unsigned int stride = blockDim.x * gridDim.x;
	// Valores calculados de cada thread
    unsigned short local_dist;
	
	while(idx < total_entradas){
		// Calculo de distancia:
		local_dist = lev_dist( local_str, first_word + (idx * HASH_SIZE * sizeof(char)) );
		// Actualizar valores:
		if(local_dist < local_min){
			local_min = local_dist;
			min_idx = idx;
		}
		// Siguiente palabra:
		idx += stride; // Numero de palabra
		
	} // End while busqueda del thread
	
	// Copia de resultados para cada thread de los minimos, back to CPU...
	out_dist[threadIdx.x + (blockDim.x * blockIdx.x)] = local_min;
	out_idx[threadIdx.x + (blockDim.x * blockIdx.x)] = min_idx;
}

/*---------------------------------------------------------------------------
 ----------------------------------------------------------------------------
 ------------------------------  MAIN PROGRAM  ------------------------------
 ----------------------------------------------------------------------------
 ---------------------------------------------------------------------------*/

void correct_usage();

int main(int argc, char **argv)
{	
    unsigned int threads_per_block = 256; // MAX THREADS PER BLOCKS
	unsigned int num_blocks = 4;
	enum input_t {performance_mode, correct_mode} mode;
	mode = performance_mode;
	// Command line inputs
	if( argc == 2 && strcmp(argv[1], "--help") == 0 )
	{
		correct_usage();
		return 0;
		cout << "Not ended!!!!!!!!" << endl;
	}
	if(argc >= 4 && strcmp(argv[1], "--grid") == 0)
	{
		threads_per_block = stoi(argv[2]);
		num_blocks = stoi(argv[3]);
	}
	if(argc == 5) 
	{
		if(strcmp(argv[4], "--correct") == 0){
			mode = correct_mode; 
		} // else ja considerat
	}
	unsigned short out_gpu_len = num_blocks * threads_per_block;
    
	if(strcmp(setlocale(LC_ALL, NULL), "C") == 0)
	{
		cout << "Tenim encoding 'C'. Canvi a nes des sistema..." << endl;
		if(setlocale(LC_ALL, "") == NULL)
		{
			cout << "Failed to set new locale\nEXIT";
			return EXIT_FAILURE;
		}
	}
	
	ifstream fitxer;
	cout << "Obrir diccionari..." << endl;
	fitxer.open("dictionary.txt");
		
	string str;
	unsigned int entradas = 0; // Maximo elementos: 4,294,967,296 -> [0, 4,294,967,296)
	
	if(!fitxer){
		cout << endl << "Diccionari no obert" << endl << "EXIT" << endl;
		return EXIT_FAILURE;	
	}
	else { // Lectura de la cantidad de entradas en el fichero:
		unsigned short longest = 0;
		cout << endl << "Diccionari obert" << endl << "Llegint..." << endl;
		getline(fitxer, str); // En caso de solo tener una entrada o poder detectar los ficheros de solo una entrada.
		while( !fitxer.eof() ){
			entradas++;
			getline(fitxer, str);
			if(longest < str.length()){
				longest = str.length();
			}
		}
		cout << "Entrades diccionari: " << entradas << endl;
		cout << "Palabra mas larga: " << longest << endl;
		if(longest > HASH_SIZE){
			cout << endl << "Macro HASH_SIZE insuficient. Minim recomanat: " << longest << endl;
			cout << "Exit" << endl;
			return EXIT_FAILURE;
		}
	}
	cout << endl << "Close file...  " << endl;
	fitxer.close();
		
	// Allotjam espai per guardar tot el diccionari. Per això tenim el nombre d'entrades
	// Llegim fixer i guardam les línies sense completar amb PADDING_CHAR -> Això ho passam a kernel...
	cout << "Allotjar memoria diccionari per " << entradas << " entrades de 25 char..." << endl;
	char *first_word;
	CUDA_CALL( cudaMallocManaged(&first_word, entradas * HASH_SIZE * sizeof(char)) );
	
	// Cridada kernel de inicialitzacio memoria GPU -> PADDING_CHARs
	//
	cout << endl << "Kernel call. Threads per block: " << threads_per_block << endl;
	cout << "k_setupPadding..." << endl;
	k_setupPadding<<<num_blocks, threads_per_block>>>(first_word, entradas);
	CUDA_CALL( cudaDeviceSynchronize() ); 
	cout << "Padding ended" << endl;
	
	// Cambio de puntero on el que trabajar para no perder origen
	char *word = first_word;

	// Lectura de fitxer i bolcat de chars
	//
	cout << endl << "Reopen file" << endl;
	fitxer.open("dictionary.txt");
	if(!fitxer){
		cout << endl << "Fitxer no obert" << endl << "EXIT" << endl;
		return EXIT_FAILURE;
	}
	cout << "Fitxer a inici" << endl;

	cout << endl << "Lectura de fitxer a memoria..." << endl;
	unsigned short i;
	while( !fitxer.eof() ){// Llegir línies senceres, despres convertir a nes nostro format de string
		getline(fitxer, str);
		i = 0;
		
		while(i < str.length()){ // Conociendo HASH_SIZE, no hace falta delimitador '\0'
			word[i] = str[i];
			i++;
		}
		// El final del diccionari sera: word + (entradas * HASH_SIZE * sizeof(char)) no inclos.
		// Salto de palabra:
		word = word + (HASH_SIZE * sizeof(char));
	}
	cout << "Reading completed" << endl;
	fitxer.close();
	cout << "Dictionary closed" << endl;
	
	// Stats:
	cout << endl << "Numero de entradas existentes: " << entradas << endl;	
	//
	// End file reading and stored in memory.
	
	//
	//
	// Declaracions comuns:
	cout << endl << "Reserva de memoria para los resultados: distancias calculadas e índice para cada thread" << endl;
	unsigned int *out_idx;
	unsigned short *out_dist;
	CUDA_CALL( cudaMallocManaged(&out_idx, out_gpu_len * sizeof(unsigned int)) );
	CUDA_CALL( cudaMallocManaged(&out_dist, out_gpu_len * sizeof(unsigned short)) );
	
	//In file
	ifstream in_file;
	cout << endl << "Documento para tomar inputs: ";
	cin >> str;
	in_file.open(str.c_str());
	if(!in_file){
        cout << endl << str << " no obert correctament. EXIT." << endl;
        return EXIT_FAILURE; 
    }
	// Out file
	ofstream out_file;
	if(mode == correct_mode)
		out_file.open("corrected.txt", ofstream::out | ofstream::app);
	else
		out_file.open("report.txt", ofstream::out | ofstream::app);
	
    if(!out_file)
    {
        cout << endl << "Sortida no oberta/creada correctament. EXIT." << endl;
        return EXIT_FAILURE; 
    }
	cout << "Resultado en fichero: corrected.txt" << endl;
	
	// Variables auxiliars per correccio:
	char *query_word;
	CUDA_CALL( cudaMallocManaged(&query_word, HASH_SIZE * sizeof(char)) );
	unsigned short _min;
	unsigned int launches = 0, corrected_w = 0, wrong_words = 0;
	char insp;
	//
	//
	// Consultes sobre memoria o correccio amb sa memoria
	//
	if(mode == correct_mode)
	{
		while ( !in_file.eof() && in_file.good() && out_file.good() )
		{
			i = 0;
			while(i < HASH_SIZE)
			{ // Get raw word
				insp = (char) in_file.peek();
				if( isalpha(insp) ) {
					in_file.get(query_word[i]);
				}
				else {
					query_word[i] = PADDING_CHAR;
				}
				i++;
			}
			// Consulta a memoria.
			k_levenshtein<<<num_blocks, threads_per_block>>>(query_word, first_word, entradas, out_idx, out_dist);
			CUDA_CALL( cudaDeviceSynchronize() );
			launches++;

			// Encontramos el resultado de menor valor
			_min = 0;
			for(unsigned short k = 0; (k < out_gpu_len) && (out_dist[_min] != 0); k++) {
				if (out_dist[_min] > out_dist[k]) {
					_min = k;
				}
			}
			if(out_dist[_min] != 0)
				corrected_w++; 
			
			// Con el mínimo tenemos el puntero a la palabra que se escribe en out_file
			word = first_word + (out_idx[_min] * HASH_SIZE * sizeof(char));
			for(unsigned char k = 0; (k < HASH_SIZE) && (word[k] != PADDING_CHAR); k++) { out_file << word[k]; }
			
			// Escriure caracters entre paraules:
			while( !isalpha((char)in_file.peek()) && !in_file.eof() ) 
			{
				in_file.get(insp);
				out_file << insp;
				if(insp == '*') { wrong_words++; }
			}
			if((launches % 10000) == 0)
				cout << "Launches: " << launches << endl;
		}
	}
	else
	{
		while( !in_file.eof() && in_file.good() )
		{
			// Input de paraula per calcular distancia:
			str.clear();
			in_file >> str;
			out_file << "Q: " << str << " ";
			
			// Relleno de lo que nos entra...
			for(unsigned short letra = 0; letra < HASH_SIZE; letra++){
				if(letra < str.length()){
					query_word[letra] = str[letra];
				} else {
					query_word[letra] = (char)PADDING_CHAR;
				}
			}

			k_levenshtein<<<num_blocks, threads_per_block>>>(query_word, first_word, entradas, out_idx, out_dist);
			CUDA_CALL( cudaDeviceSynchronize() );
			launches++;
			
			// Bucle de resultats...
			cout << endl << "Look for minimum dist result..." << endl;
			_min = 0;
			for(i = 0; i < out_gpu_len; i++){
				if(out_dist[i] <= out_dist[_min]){
					_min = i;
				}
			}

			// Apuntamos a la palabra seleccionada y al fichero
			word = first_word + ( out_idx[_min] * HASH_SIZE * sizeof(char) ); // Ponemos el puntero en la palabra que necesitamos...
			for(unsigned char k = 0; (k < HASH_SIZE) && (word[k] != PADDING_CHAR); k++) { out_file << word[k]; }
			out_file << " (" << out_dist[_min] << ")" << endl;
		}
	}
	
	cout << "Processing ended" << endl;
	// Tancam I/O files:
	in_file.close(); out_file.close();
	cout << "Archivos cerrados" << endl;
	
	//
	//
	//
	//
		
	CUDA_CALL( cudaFree(first_word) );
	CUDA_CALL( cudaFree(query_word) ); 
	CUDA_CALL( cudaFree(out_idx)    );
	CUDA_CALL( cudaFree(out_dist)   );

	cout << "cudaDeviceReset()..." << endl;
	CUDA_CALL( cudaDeviceReset() );
	cout << "Device cleared" << endl;

	if(mode == correct_mode)
	{
		cout << endl << "======================== RUN INFO ========================" << endl;
		cout << " - Threads tot: " << out_gpu_len << endl;
		cout << " - Blocks:" << num_blocks << '\t' << "Threads: " << threads_per_block << endl << endl;
		cout << " - Words searched: " << launches << endl;
		cout << " - Total corrections: " << corrected_w << endl;
		cout << " - Real alterations: " << wrong_words << endl;
	}
	else
	{
		cout << endl << "======================== RUN INFO ========================" << endl;
		cout << " - Threads tot: " << out_gpu_len << endl;
		cout << " - Blocks:" << num_blocks << '\t' << "Threads: " << threads_per_block << endl << endl;
		cout << " - Words consulted: " << launches << endl;
	}
	
    return 0;
}


// Definimos correct_usage:
void correct_usage()
{
	cout << endl << "Author: Jover Mulet, Mateu. Contact @ mateu.jover@gmail.com" << endl;
	cout << "Electrical and Electronics Engineer from the U. of the Balearic Islands" << endl;
	cout << endl << "Setting the computational grid. Correct use for Ubuntu terminal command line options:" << endl;
	cout << " --grid [Threads per block (default: 256)] [Number of blocks(default: 4)] [--correct or --test(default)]" << endl;
	cout << "Check your GPGPU's specs for a better usage. Desired multiples of 32 for Threads per block." << endl;
		
	cout << "Displaying help, as it has been done. Just the parameter --help " << endl;
}