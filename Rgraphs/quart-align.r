library("rhdf5")

args <- commandArgs(trailingOnly = TRUE)
type = args[1]
arg_offset = 0
data_file = ""

data_file = args[2]
png_file = args[3]
data_dir = ""
start = 0
stop = 0
maxy = 0

if (type == "hdf5") {
    start <- h5read(data_file,"/stats/start")
    stop <- h5read(data_file,"/stats/stop")
    maxy <- h5read(data_file,"/stats/maxy")

    start = start[1][1]
    stop = stop[1][1]
    maxy = maxy[1][1]

    newdata = t(rep(NA,stop))

    arg_offset = 3
} else {

    data_dir = data_file
    data_files=list.files(path = data_dir, pattern = "align")

    start = as.integer(args[4])
    stop = as.integer(args[5])
    maxy = as.integer(args[6])

    print(paste("range",start,stop))
    newdata = t(rep(NA,length(data_files)))
    #colnames(data)<-start:stop

    arg_offset = 6
}


jobnum = ""
if (length(args) > arg_offset) {
    jobnum = paste(" for Job ID ", args[arg_offset+1])
}
im_width = 2000
if (length(args) > arg_offset+1) {
    im_width = strtoi(args[arg_offset+2])
}
im_height = 900
if (length(args) > arg_offset+2) {
    im_height = strtoi(args[arg_offset+3])
}


print(paste(start,",",stop,",",maxy))
png(png_file, width=im_width, height=im_height, type="cairo")

bar_step_size <- 1
whisk_color <- "gray40"
if (im_width < 1000) {
    bar_step_size = 3
    whisk_color <- "gray60"
}

num_boxes <- stop - start + 1
step_size <- ceiling(10 / (im_width / num_boxes))
box_range <- seq(start, num_boxes + step_size, step_size)
bars_to_use <- seq(start, num_boxes, bar_step_size)

boxplot(newdata,
        main = paste("Alignment Length vs Alignment Score", jobnum),
        whiskcol = whisk_color,
        staplecol = whisk_color,
        ylab = "Alignment Length",
        xlab = "Alignment Score",
        ylim = range(0,maxy),
        xaxt = "n",
        frame = F)

for (i in bars_to_use){
    key=i #i+start-1
    #so this is an array,has to be rotated
    if (type == "hdf5") {
        print(paste0("/align/",key))
        newdata = t(h5read(data_file,paste0("/align/",key)))
    } else {
   #     key=i-start+1
        idx = i - start + 1
        full_path = paste(data_dir,"/",data_files[idx],sep='')
        print(full_path)
        newdata = read.table(full_path, header=TRUE, sep="\t", check.names = FALSE)
    }
    if (length(newdata) == 0)
        next
    boxplot(newdata,
            col = "red", 
            border = "blue",  
            whiskcol = whisk_color,
            staplecol = whisk_color,
            add = TRUE, 
            xaxt = "n", 
            yaxt = "n", 
            at=key, 
            range = 0,
            frame=F)
    rm(newdata)
    gc()
}
axis(side = 1, box_range)

dev.off()

