
select * from TaskAssignments
select * from Tasks
select * from Employees
--1a:Trigger trg_TaskAssignments_Insert bắt lệnh INSERT trên bảng
TaskAssignments sao cho mỗi khi bổ sung một dòng dữ liệu trong bảng này thì tính lại số lượng
nhân viên đã được giao việc thực hiện công việc (cột NumOfAssigned của bảng Tasks)

if exists ( select * from sys.objects where name = 'trg_TaskAssignments_Insert')
	drop trigger trg_TaskAssignments_Insert;
go

create trigger trg_TaskAssignments_Insert
on TaskAssignments 
for insert 
as
begin
	set nocount on;

	declare @TaskId int;
	select @TaskId = TaskId from inserted;

	update Tasks
	set NumOfAssigned = NumOfAssigned +1
	where TaskId = @TaskId

end
go

--test case:
insert into TaskAssignments values(1,2,'2023/01/01','2023/02/02')

--1b (1,5 điểm) Trigger trg_TaskAssignments_Update bắt lệnh UPDATE trên bảng
TaskAssignments sao cho mỗi khi cập nhật giá trị cột EndDate của một dòng trong bảng này thì
tính lại số lượng nhân viên đã hoàn thành công việc được giao (cột NumOfFinished của bảng
Tasks)
Lưu ý: Một công việc được giao là hoàn thành nếu giá trị của cột EndDate khác NULL

if exists ( select * from sys.objects where name = 'trg_TaskAssignments_Update')
	drop trigger trg_TaskAssignments_Update;
go

create trigger trg_TaskAssignments_Update
on TaskAssignments 
for update 
as
begin
	set nocount on;

	if update(EndDate)
		begin
		declare @TaskId int,
				@EndDate_Old date,
				@EndDate_New date;
		select @TaskId = TaskId, @EndDate_Old = EndDate
		from deleted

		select @EndDate_New = EndDate
		from inserted

		if(@EndDate_Old is NULL) and (@EndDate_New is not null)
			begin
				Update Tasks
				set NumOfFinished +=1
				where TaskId = @TaskId 
				--Ngoài ra, lệnh "return;" sẽ kết thúc trigger ngay lập tức sau khi thực hiện cập nhật đầu tiên, dẫn đến việc 
				--trigger sẽ chỉ thực hiện được một lần cập nhật duy nhất.
			end
		if(@EndDate_Old is not NULL) and (@EndDate_New is null)
			begin
				Update Tasks
				set NumOfFinished -=1
				where TaskId = @TaskId
				
			end
		end

end
go

--test case:
update TaskAssignments
set EndDate = (null)
where TaskId = 3
select * from Tasks

--2a Viết thủ tục sau đây:
 proc_TaskAssignments_Create
@TaskId int,2
@EmployeeId int,
@StartDate date
@Result nvarchar(255) output
Có chức năng giao việc có mã @TaskId cho nhân viên có mã @EmployeeId. Tham số đầu ra
@Result trả về chuỗi rỗng trong trường hợp giao việc thành công; Trong trường hợp ngược lại,
tham số @Result trả về chuỗi cho biết lý do không giao được việc

if exists ( select * from sys.objects where name = 'proc_TaskAssignments_Create')
	drop procedure proc_TaskAssignments_Create;
go

create procedure proc_TaskAssignments_Create
	@TaskId int,
	@EmployeeId int,
	@StartDate date,
	@Result nvarchar(255) output
as
begin
	set nocount on;
	--
	if not exists ( select * from Tasks where TaskId = @TaskId)
	begin
		set @Result =N'Nhiệm vụ k tồn tại !';
		return;
	end

	if not exists ( select * from Employees where EmployeeId= @EmployeeId)
	begin
		set @Result =N'Nhân viên k tồn tại !';
		return;
	end

	if(@StartDate is null)
		begin
		set @Result =N'StartDate sai!';
		return;
	end

	if not exists ( select * from TaskAssignments where TaskId = @TaskId and EmployeeId= @EmployeeId)
	begin
		set @Result =N'Nhiệm vụ đã được giao từ trước cho nhân viên này!';
		return;
	end
	--
	insert into TaskAssignments(TaskId, EmployeeId,StartDate)
	values (@TaskId, @EmployeeId,@StartDate)
	
	set @Result = N'';
end
go

--test case:
declare @r nvarchar(255)
execute proc_TaskAssignments_Create
	@TaskId =2,
	@EmployeeId =3,
	@StartDate = ' 2020/02/03',
	@Result  = @r output;
select @r;

--2b  proc_TaskAssignments_Update
@TaskId int,
@EmployeeId int,
@EndDate date,
@Result nvarchar(255) output
Có chức năng cập nhật ngày hoàn thành công việc (cột EndDate của bảng TaskAssignments).
Tham số đầu ra @Result trả về chuỗi rỗng nếu việc cập nhật thành công, ngược lại tham số này trả
về chuỗi cho biết lý do không cập nhật được dữ liệu.


if exists ( select * from sys.objects where name = 'proc_TaskAssignments_Update')
	drop procedure proc_TaskAssignments_Update;
go

create procedure proc_TaskAssignments_Update
	@TaskId int,
	@EmployeeId int,
	@EndDate date,
	@Result nvarchar(255) output
as
begin
	set nocount on;
	--
	if not exists(select * from TaskAssignments
				where TaskId = @TaskId and EmployeeId = @EmployeeId)
		begin
			set @Result =N'Nhiệm vụ và nhân viên không ăn khớp!';
			return;
		end
	IF EXISTS(SELECT * FROM TaskAssignments WHERE TaskId = @TaskId AND (EndDate > GETDATE() OR EndDate < StartDate))
		BEGIN
			SET @Result = N'Ngày sửa đổi không hợp lệ!';
			RETURN;
		END

	--
	update TaskAssignments
	set EndDate = @EndDate
	where TaskId = @TaskId and EmployeeId = @EmployeeId

	set @Result = '';
end
go

--Test case:
declare @r nvarchar(255);
execute proc_TaskAssignments_Update
	@TaskId =2,
	@EmployeeId =3,
	@EndDate ='2024/02/02',
	@Result = @r output;
select @r;

--2c  proc_Employees_Select
@SearchName nvarchar(255) = N’’,
@Page int = 1,
@PageSize int = 20,
@RowCount int output,
@PageCount int output
Có chức năng tìm kiếm và hiển thị danh sách nhân viên dưới dạng phân trang dữ liệu. Trong đó,
@SearchName là giá trị cần tìm (tìm kiếm tương đối theo họ tên, nếu tham số này là chuỗi rỗng thì
không tìm kiếm), @Page là trang cần hiển thị, @PageSize là số dòng dữ liệu được hiển thị trên mỗi
trang, tham số đầu ra @RowCount cho biết tổng số dòng dữ liệu và tham số đầu ra @PageCount cho
biết tổng số trang

if exists ( select * from sys.objects where name = 'proc_Employees_Select')
	drop procedure proc_Employees_Select;
go

create procedure proc_Employees_Select
@SearchName nvarchar(255) = N'',
@Page int = 1,
@PageSize int = 20,
@RowCount int output,
@PageCount int output
as
begin
	set nocount on;
	set @SearchName = '%' + @SearchName + '%';
	if (@Page <1) set @Page = 1;
	if (@PageSize <1) set @PageSize = 20;

	select @RowCount =count(*)  
	from Employees
	where EmployeeName = @SearchName

	set @PageCount = @RowCount/@PageSize;
	if @RowCount%@PageSize >0 set @PageCount +=1

	select *
	from 
	(
		select *, ROW_NUMBER()over(order by EmployeeName) as RowNumber
		from Employees
		where EmployeeName = @SearchName
	) as t
	where t.RowNumber between (@Page -1)*@PageSize +1 and @Page*@PageSize

end
go

--test case:
declare @r int,@p int;
execute proc_Employees_Select
	@SearchName = N'',
	@Page =1,
	@PageSize = 20,
	@RowCount =@r output,
	@PageCount =@p output
select @r,@p;


--2d proc_SummaryEndedTaskByDate
@From date,
@To date
Có chức năng thống kê số lượt công việc đã được ghi nhận hoàn thành của mỗi ngày trong khoảng
thời gian từ ngày @From đến ngày @To. Yêu cầu kết quả thống kê phải hiển thị đầy đủ tất cả các
ngày trong khoảng thời gian trên (những ngày không có công việc được ghi nhận hoàn thành thì
hiển thị với số lượng là 0)

if exists ( select * from sys.objects where name = 'proc_SummaryEndedTaskByDate')
	drop procedure proc_SummaryEndedTaskByDate;
go

create procedure proc_SummaryEndedTaskByDate
	@From date,
	@To date
as
begin
	set nocount on;

	declare @tbl table
	(
	TimeOfFinish date
	)
	declare @d date;
	set @d = @From
	while(@d<=@To)
		begin
			insert into @tbl values (@d);
			set @d = DATEADD(day,1,@d);
		end
	select t1.TimeOfFinish, t2.NumOfFinish
	from @tbl as t1 
		left join
		(
		select EndDate, count(TaskId) as NumOfFinish
		from TaskAssignments
		where EndDate between @From and @To
		group by EndDate
		) as t2
		on t1.TimeOfFinish = t2.EndDate
end
go

--test case:
proc_SummaryEndedTaskByDate
	@From ='2020/01/01',
	@To ='2022/02/02'

--3 Câu 3: Viết các hàm sau đây
a. (1 điểm) func_CountNotEndTasks(@EmployeeId int) có chức năng đếm số lượng công
việc mà nhân viên có mã @EmployeeId chưa hoàn thành.
--3a
if exists( select * from sys.objects where name = 'func_CountNotEndTasks')
	drop function func_CountNotEndTasks;
go

create function func_CountNotEndTasks(@EmployeeId int)
returns int
as
begin
	declare @Count int;

	select @Count = count(*)
	from TaskAssignments
	where EmployeeId = @EmployeeId and EndDate is null
	
	return @Count;
end
go

--test case:
select dbo.func_CountNotEndTasks(3)

--3b b. (1,5 điểm) func_SummaryEndedTasksByDate(@From date, @To date) có chức năng trả
về bảng thống kê số lượng công việc hoàn thành của mỗi ngày trong khoảng thời gian từ ngày
@From đến ngày @To. Yêu cầu kết quả thống kê phải hiển thị đầy đủ tất cả các ngày trong khoảng
thời gian trên (những ngày không có công việc được ghi nhận hoàn thành thì hiển thị với số lượng là 0)

if exists( select * from sys.objects where name = 'func_SummaryEndedTasksByDate')
	drop function func_SummaryEndedTasksByDate;
go

create function func_SummaryEndedTasksByDate(@From date, @To date)
returns @tbl table
(
Ngay_Hoan_Thanh date,
So_Luong int
)
as
begin
	insert into  @tbl(Ngay_Hoan_Thanh ,So_Luong)
		select EndDate, count(TaskId) as NumOfFinish
		from TaskAssignments
		where EndDate between @From and @To
		group by EndDate;

	declare @d date;
	set @d = @From;
	while(@d<=@To)
		begin
			if not exists(select * from TaskAssignments where EndDate = @d)
				insert into @tbl(Ngay_Hoan_Thanh ,So_Luong) values(@d,0)
			set @d = DATEADD(day,1,@d)
		end
	return;
end
go

--test case:
select * from dbo.func_SummaryEndedTasksByDate('2023/02/02','2023/03/03')
order by Ngay_Hoan_Thanh