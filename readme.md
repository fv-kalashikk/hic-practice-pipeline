# Пайплайн для домашнего задания 1 по Hi-C

- `run_hic_pipeline.sh` - пайплайн

## 1. Что делает `run_hic_pipeline.sh`

**Выполняется один раз для всех образцов** (так как референс и Juicer общие):

1. `prepare_reference` — скачивает T2T-CHM13v2.0, распаковывает, переименовывает хромосомы, индексирует `bwa`, считает `chrom.sizes`.
2. `install_juicer` — клонирует версию Juicer
3. `prepare_restriction_sites` — генерирует файл сайтов `DpnII`.

**Выполняется для каждого образца** :

4. `download_sample` — скачивает R1/R2 с сервера.
5. `run_fastqc_for_sample` — FastQC по сырым ридам.
6. `run_cutadapt_for_sample` — обрезка адаптеров/качества
7. `prepare_juicer_dir_for_sample` — создает `data/juicer/<sample>/fastq/` с симлинками на обрезанные риды.
8. `run_juicer_for_sample` — запускает `juicer.sh` с ферментом `DpnII`.
9. `finalize_sample` — копирует `inter_30.hic` в `results/hic/<sample>.inter_30.hic`.

Каждый шаг проверяет, не выполнен ли он уже (файл существует и не пустой), и пропускает себя, если да.

## 2. Запуск

Из директории практики (там, где `data/`, `results/`, `scripts/`, `tools/`):

```bash
conda activate hic_practice

chmod +x run_hic_pipeline.sh validate_pipeline.sh

# запуск всех 4 образцов
./run_hic_pipeline.sh
```

## Итоговая структура результатов

После успешного запуска получаются файлы:

```text
results/hic/MoPh7.inter_30.hic
results/hic/MoPh11.inter_30.hic
results/hic/MoPh14.inter_30.hic
results/hic/MoPh15.inter_30.hic
```

и для каждого образца — лог `results/cutadapt/<sample>.cutadapt.log`, отчеты FastQC в `results/fastqc_raw/`, и полная рабочая директория Juicer в `data/juicer/<sample>/`
# Hi-C pipeline: от сырых ридов до .hic файлов
 
Пайплайн для обработки paired-end Hi-C данных — от сырых FASTQ до файлов `.hic`,
которые можно открыть в Juicebox для визуализации карт контактов.
 
## Что делает пайплайн
 
Для каждого образца последовательно выполняется:
 
1. Скачивание FASTQ файлов
2. Контроль качества FastQC
3. Обрезка адаптеров через cutadapt
4. Запуск Juicer для получения карты контактов в виде .hic файлов
5. Сохранение итогового `.hic` файла в `results/hic/`

Перед обработкой образцов скрипт проверяет наличие референсного генома, индексов bwa, файла сайтов рестрикции и самого Juicer — если чего-то нет, скачивает и создает.
 
## Структура директорий
 
После клонирования репозитория нужно создать папки и положить туда нужные файлы.
Скрипт создаст папки и скачает всё сам, но если часть файлов уже есть — он их увидит и пропустит.
 
```
.
├── run_hic_pipeline.sh       # основной скрипт
├── scripts/
│   └── rename_chroms_t2t.py  # переименование хромосом из NCBI-формата в chr*
├── data/
│   ├── raw/                  # сырые риды (не в репозитории)
│   ├── trimmed/              # обрезанные риды (не в репозитории)
│   ├── reference/            # референс и индексы (не в репозитории)
│   └── juicer/               # рабочие папки Juicer (не в репозитории)
├── results/
│   ├── fastqc_raw/           # отчеты FastQC
│   ├── cutadapt/             # логи cutadapt
│   └── hic/                  # итоговые .hic файлы (не в репозитории)
└── tools/
    └── juicer/               # клонируется автоматически
```
 
> **Примечание:** `tools/juicer` не включен в репозиторий — он клонируется автоматически
 
## Как запустить
 
```bash
git clone https://github.com/fv-kalashikk/hic-practice-pipeline.git
cd hic-practice-pipeline
 
bash run_hic_pipeline.sh 2>&1 | tee pipeline.log
```
 
 
## Референсный геном
 
Использован T2T-CHM13v2.0 (человек, теломер-теломер сборка):
`GCF_009914755.1`, скачивается с NCBI FTP автоматически.
 
Хромосомы переименованы из NCBI-формата (`NC_xxxxxx.x`) в `chr1`, `chr2`, ...,`chrX`, `chrM` скриптом `scripts/rename_chroms_t2t.py`.
 
Фермент рестрикции: **DpnII**.
 
## Визуализация результатов
 
Открыть `.hic` файлы можно в [Juicebox](https://github.com/aidenlab/Juicebox/releases):
 
```bash
java -jar tools/Juicebox.jar
```
 
`File → Open → Local` → выбрать файл из `results/hic/`