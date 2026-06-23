#!/usr/bin/env bash

# пайплайн для обработки Hi-C образцов
# запускать из папки day1_HiC_practice

##### НАЧАЛО - задаем все нужные переменные + образцы которые будем скачивать 
# Обязательно наличие файлов T2T_human.fna, chrom.sizes и restriction_sites_DpnII.txt, 
# а так же установленный juicer. Если всего этого нет, то пайплайн это сделает, 
# если это есть, то будет использовано 

REF=data/reference/T2T_human.fna # должна быть папка для референса 
CHROM_SIZES=data/reference/chrom.sizes
RESTRICTION_SITES=data/reference/restriction_sites_DpnII.txt
JUICER_DIR=tools/juicer

BASE_URL="https://genedev.bionet.nsc.ru/ftp/_RawReads/2025-05-23MyGenetics"

SAMPLES=("MoPh7" "MoPh11" "MoPh14" "MoPh15")

R1_FILES=(
    "Copy of MoPh7_S85_L001_R1_001.fastq.gz"
    "Copy of MoPh11_S86_L001_R1_001.fastq.gz"
    "Copy of MoPh14_S87_L001_R1_001.fastq.gz"
    "Copy of MoPh15_S88_L001_R1_001.fastq.gz"
)
R2_FILES=(
    "Copy of MoPh7_S85_L001_R2_001.fastq.gz"
    "Copy of MoPh11_S86_L001_R2_001.fastq.gz"
    "Copy of MoPh14_S87_L001_R2_001.fastq.gz"
    "Copy of MoPh15_S88_L001_R2_001.fastq.gz"
)

mkdir -p data/raw data/trimmed data/reference results/fastqc_raw results/cutadapt results/hic

##### ПОДГОТОВКА ОКРУЖЕНИЯ 
# подключаем conda к текущей оболочке
source "$(conda info --base)/etc/profile.d/conda.sh"
 
# ищем нужное нам окружение если оно уже существует 
if conda env list | grep -q "hic_practice"; then
    echo "Окружение hic_practice уже существует"
else
    echo "Создаю окружение hic_practice..."
    conda create -n hic_practice -c conda-forge -c bioconda \
        fastqc cutadapt bwa samtools openjdk=11 wget -y
fi
 
conda activate hic_practice
 
# проверяем что нужные инструменты есть в окружении
# на случай если окружение было создано раньше но пустое
TOOLS_NEEDED="fastqc cutadapt bwa samtools java wget"
TOOLS_MISSING=""
 
for tool in $TOOLS_NEEDED; do
    if ! command -v $tool &> /dev/null; then
        TOOLS_MISSING="$TOOLS_MISSING $tool"
    fi
done
 
if [ -n "$TOOLS_MISSING" ]; then
    echo "Не найдены инструменты:$TOOLS_MISSING - устанавливаю..."
    conda install -n hic_practice -c conda-forge -c bioconda $TOOLS_MISSING -y
else
    echo "Все необходимые инструменты найдены"
fi

##### ПОДГОТОВКА референса, juicer и файла сайтов рестрикции

# референс 
if [ ! -f data/reference/T2T_human.fna.gz ]; then
    echo "Скачиваю референс..."
    wget -O data/reference/T2T_human.fna.gz \
        https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/009/914/755/GCF_009914755.1_T2T-CHM13v2.0/GCF_009914755.1_T2T-CHM13v2.0_genomic.fna.gz
else
    echo "T2T_human.fna.gz уже скачан, пропускаю"
fi

if [ ! -f data/reference/T2T_human.fna ]; then
    echo "Распаковываю референс..."
    gzip -dkf data/reference/T2T_human.fna.gz
else
    echo "T2T_human.fna уже есть, пропускаю"
fi

# скрипт переименовывает хромосомы из NCBI-формата в chr1, chr2, chrX, chrM
if [ ! -f data/reference/T2T_human.rename_chroms.tsv ]; then
    echo "Переименовываю хромосомы..."
    python3 scripts/rename_chroms_t2t.py
else
    echo "Хромосомы уже переименованы, пропускаю"
fi

# bwa index создает несколько файлов, проверяем по .bwt
if [ ! -f data/reference/T2T_human.fna.bwt ]; then
    echo "Индексирую референс (это займет долгое время)..."
    bwa index data/reference/T2T_human.fna
else
    echo "Индекс bwa уже есть, пропускаю"
fi

if [ ! -f data/reference/chrom.sizes ]; then
    echo "Создаю chrom.sizes..."
    samtools faidx data/reference/T2T_human.fna
    cut -f1,2 data/reference/T2T_human.fna.fai > data/reference/chrom.sizes
else
    echo "chrom.sizes уже есть, пропускаю"
fi

# --- juicer ---
if [ ! -f tools/juicer/scripts/juicer.sh ]; then
    echo "Клонирую Juicer..."
    git clone \
        --branch juicer_course_version \
        --single-branch \
        https://github.com/dpanc2/OMICS_course_spring_2026.git \
        tools/juicer
else
    echo "Juicer уже установлен, пропускаю"
fi

# файл сайтов рестрикции
if [ ! -f data/reference/restriction_sites_DpnII.txt ]; then
    echo "Генерирую файл сайтов рестрикции DpnII..."
    python3 tools/juicer/misc/generate_site_positions.py \
        DpnII \
        T2T_human \
        data/reference/T2T_human.fna
    mv T2T_human_DpnII.txt data/reference/restriction_sites_DpnII.txt
else
    echo "Файл сайтов рестрикции уже есть, пропускаю"
fi

##### ОБРАБОТКА ОБРАЗЦОВ

# ${#SAMPLES[@]} - длина массива SAMPLES
# это позволяет просто добавить новые образцы в массивы выше
# и не менять больше ничего в скрипте
N_SAMPLES=${#SAMPLES[@]}
echo "В обработке $N_SAMPLES образцов"

for (( i=0; i<N_SAMPLES; i++ )); do

    SAMPLE=${SAMPLES[$i]}
    R1_NAME=${R1_FILES[$i]}
    R2_NAME=${R2_FILES[$i]}

    # если итоговый .hic уже есть то образец уже обработан и мы его пропускаем
    if [ -f results/hic/${SAMPLE}.inter_30.hic ]; then
        echo "========= $SAMPLE уже обработан, пропускаю ========="
        continue 
    fi
 
    echo "========= Обрабатываю $SAMPLE ========="

    # шаг 1: скачиваем риды
    # пробелы в имени файла надо заменить на %20 для URL
    # ${var// /%20} заменяет все пробелы на %20 в строке
    R1_URL="${BASE_URL}/${R1_NAME// /%20}"
    R2_URL="${BASE_URL}/${R2_NAME// /%20}"

    wget --no-check-certificate -O data/raw/${SAMPLE}_R1.fastq.gz "$R1_URL"
    wget --no-check-certificate -O data/raw/${SAMPLE}_R2.fastq.gz "$R2_URL"

    # шаг 2: проверка качества fastqc
    fastqc data/raw/${SAMPLE}_R1.fastq.gz data/raw/${SAMPLE}_R2.fastq.gz \
        -o results/fastqc_raw

    # шаги 3 и 4: обрезка адаптеров с помощью cutadapt
    cutadapt \
        -q 20 \
        -m 70 \
        -a AGATCGGAAGAGCACACGTCTGAACTCCAGTCA \
        -o data/trimmed/${SAMPLE}_R1.trimmed.fastq.gz \
        -p data/trimmed/${SAMPLE}_R2.trimmed.fastq.gz \
        data/raw/${SAMPLE}_R1.fastq.gz \
        data/raw/${SAMPLE}_R2.fastq.gz \
        > results/cutadapt/${SAMPLE}.cutadapt.log 2>&1

    # шаг 5: подготовка папки для juicer (без нужного расположения папок не работает)
    mkdir -p data/juicer/${SAMPLE}/fastq

    # juicer ищет риды в папке fastq/ внутри директории эксперимента
    # используем симлинки
    ln -sf $(pwd)/data/trimmed/${SAMPLE}_R1.trimmed.fastq.gz \
        data/juicer/${SAMPLE}/fastq/${SAMPLE}_R1.fastq.gz
    ln -sf $(pwd)/data/trimmed/${SAMPLE}_R2.trimmed.fastq.gz \
        data/juicer/${SAMPLE}/fastq/${SAMPLE}_R2.fastq.gz

    # шаг 6: запуск juicer
    bash ${JUICER_DIR}/scripts/juicer.sh \
        -D $(pwd)/${JUICER_DIR} \
        -d $(pwd)/data/juicer/${SAMPLE} \
        -g T2T_human \
        -z $(pwd)/${REF} \
        -p $(pwd)/${CHROM_SIZES} \
        -y $(pwd)/${RESTRICTION_SITES} \
        -s DpnII \
        -t 4

    # шаг 7: копируем результат
    cp data/juicer/${SAMPLE}/aligned/inter_30.hic results/hic/${SAMPLE}.inter_30.hic

    echo "========= $SAMPLE готов ========="

done

echo "Все образцы обработаны!"
echo "Результаты в results/hic/"
ls -lh results/hic/
