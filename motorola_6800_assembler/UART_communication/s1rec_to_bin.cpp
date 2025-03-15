#include <iostream>
#include <string>
#include <vector>
#include <fstream>

constexpr int LENGHT_OF_BYTE = 2;

bool srec_to_bin(const std::string& inputFileName) 
{
    std::ifstream inputFile(inputFileName);
    if(!inputFile.is_open()) 
    {
        std::cerr << "Error: Could not open: " << inputFileName << std::endl;
        return false;
    }
    
    std::vector<std::string> fileContents;
    std::string line;
    
    while(std::getline(inputFile, line)) 
    {
        fileContents.emplace_back(line);
    }
    
    inputFile.close();

    if(fileContents.empty()) 
    {
        std::cerr << "Error: File " << inputFileName << " is empty" << std::endl;
        return false;
    }
    
    // Remove the last line because it does not contain any data needed for the program
    fileContents.pop_back();

    for(size_t i = 0; i < fileContents.size(); i++)
    {   
        fileContents[i] = fileContents[i].substr(8);    // Works only with S1 record type
        fileContents[i].erase(fileContents[i].size() - 2);
    }
    
    std::vector<char> pairs;
    std::string pair;

    // Group the chars by pairs so they make bytes and transform them into hex numbers
    for(size_t i = 0; i < fileContents.size(); i++) 
    {
        for(size_t j = 0; j < fileContents[i].size(); j += LENGHT_OF_BYTE) 
        {
            pair = fileContents[i].substr(j, LENGHT_OF_BYTE);
            pairs.emplace_back(static_cast<char>(std::stoi(pair, nullptr, 16)));
        }
    }

    std::string outputFilename = inputFileName;
    size_t dotPos = outputFilename.rfind(".s19");

    if(dotPos != std::string::npos) 
    {
        outputFilename.replace(dotPos, 4, ".bin");
    } 
    else 
    {
        outputFilename += ".bin";
    }

    std::ofstream binFile(outputFilename, std::ios::binary);

    if(!binFile.is_open()) 
    {
        std::cerr << "Error: Could not create: " << outputFilename << std::endl;
        return false;
    }

    binFile.write(reinterpret_cast<const char*>(pairs.data()), pairs.size());
    binFile.close();

    std::cout << "Successfully written to: " << outputFilename << std::endl;
    
    return true;
}

int main(int argc, char* argv[])
{
    if(argc < 2) 
    {
        std::cerr << "Usage: " << argv[0] << " <input_file.asm>" << std::endl;
        exit(1);
    }

    std::string inputFileName = argv[1];
    std::string command = "..\\bin\\as0 " + inputFileName;
    int result = std::system(command.c_str());

    if(result != 0) 
    {
        std::cerr << "Error: Failed to execute assembler command!" << std::endl;
        exit(2);
    }

    std::string s19File = inputFileName.substr(0, inputFileName.find_last_of('.')) + ".s19";

    srec_to_bin(s19File);

    return 0;
}
